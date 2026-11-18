# frozen_string_literal: true

class AddIdempotencyKeyToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :idempotency_key, :string
    add_index :documents, [ :tenant_id, :idempotency_key ],
              unique: true,
              where: "idempotency_key IS NOT NULL",
              name: "index_documents_on_tenant_id_and_idempotency_key"
  end
end
