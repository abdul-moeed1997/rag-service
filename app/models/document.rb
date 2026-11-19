# frozen_string_literal: true

class Document < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes
  MAX_CONTENT_BYTES = MAX_FILE_SIZE
  PENDING = "pending"
  PROCESSING = "processing"
  READY = "ready"
  FAILED = "failed"
  STATUSES = [ PENDING, PROCESSING, READY, FAILED ].freeze
  SOURCE_TYPES = %w[text pdf html].freeze
  DEFAULT_NAMESPACE = "default"
  NAMESPACE_FORMAT = /\A[a-zA-Z0-9][a-zA-Z0-9._-]{0,62}\z/

  belongs_to :tenant
  has_many :chunks, dependent: :destroy
  has_one_attached :file

  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :namespace, presence: true, format: { with: NAMESPACE_FORMAT }, length: { maximum: 63 }
  validates :idempotency_key, length: { maximum: 255 }, allow_nil: true
  validate :content_or_file_present
  # Only on create: ingest later stores extracted text here, which is bounded by the file limit.
  validate :content_within_limit, on: :create
  validate :supported_file_type, if: -> { file.attached? }
  validate :file_size_within_limit, if: -> { file.attached? }

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }
  scope :in_namespace, ->(namespace) { where(namespace: namespace) }

  # Atomically moves a document back to pending unless an ingest run holds it.
  # Returns false when the document is currently processing.
  def request_reindex!
    updated = self.class.where(id: id).where.not(status: PROCESSING)
                  .update_all(status: PENDING, error_message: nil, updated_at: Time.current)
    reload
    updated.positive?
  end

  private

  def content_or_file_present
    return if content.present? || file.attached?

    errors.add(:base, "content or file is required")
  end

  def content_within_limit
    return if content.to_s.bytesize <= MAX_CONTENT_BYTES

    errors.add(:content, "is too large (max #{MAX_CONTENT_BYTES / 1.megabyte} MB)")
  end

  def supported_file_type
    return if Ingest::TextExtractor.supported?(file.content_type, file.filename.to_s)

    errors.add(:file, "must be a text, HTML, or PDF file")
  end

  def file_size_within_limit
    return if file.byte_size <= MAX_FILE_SIZE

    errors.add(:file, "is too large (max #{MAX_FILE_SIZE / 1.megabyte} MB)")
  end
end
