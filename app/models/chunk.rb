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
  # Vectors from different models are not comparable. NULL = embedded before
  # model tracking existed; those are assumed to match the configured model.
  scope :embedded_with, ->(model_id) { where(embedding_model: [ model_id, nil ]) }
  scope :stale_for, ->(model_id) { where.not(embedding_model: [ model_id, nil ]) }
end
