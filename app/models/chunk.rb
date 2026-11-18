# frozen_string_literal: true

class Chunk < ApplicationRecord
  belongs_to :tenant
  belongs_to :document

  has_neighbors :embedding

  validates :position, presence: true
  validates :content, presence: true
  validates :namespace, presence: true

  scope :for_tenant, ->(tenant) { where(tenant_id: tenant.id) }
  scope :in_namespace, ->(namespace) { where(namespace: namespace) }
  scope :embedded, -> { where.not(embedding: nil) }
end
