# frozen_string_literal: true

class Document < ApplicationRecord
  MAX_FILE_SIZE = 10.megabytes
  STATUSES = %w[pending processing ready failed].freeze
  SOURCE_TYPES = %w[text pdf].freeze

  belongs_to :tenant
  has_many :chunks, dependent: :destroy
  has_one_attached :file

  validates :source_type, presence: true, inclusion: { in: SOURCE_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validate :content_or_file_present
  validate :supported_file_type, if: -> { file.attached? }
  validate :file_size_within_limit, if: -> { file.attached? }

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }

  private

  def content_or_file_present
    return if content.present? || file.attached?

    errors.add(:base, "content or file is required")
  end

  def supported_file_type
    return if Ingest::TextExtractor.supported?(file.content_type, file.filename.to_s)

    errors.add(:file, "must be a text or PDF file")
  end

  def file_size_within_limit
    return if file.byte_size <= MAX_FILE_SIZE

    errors.add(:file, "is too large (max #{MAX_FILE_SIZE / 1.megabyte} MB)")
  end
end
