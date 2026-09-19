# frozen_string_literal: true

class Document < ApplicationRecord
  belongs_to :tenant
  has_many :chunks, dependent: :destroy

  STATUSES = %w[pending processing ready failed].freeze

  validates :source_type, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :content, presence: true

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }
end
