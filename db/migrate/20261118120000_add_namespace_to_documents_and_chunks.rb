# frozen_string_literal: true

class AddNamespaceToDocumentsAndChunks < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :namespace, :string, null: false, default: "default"
    add_column :chunks, :namespace, :string, null: false, default: "default"

    add_index :documents, [ :tenant_id, :namespace ]
    add_index :chunks, [ :tenant_id, :namespace ]
  end
end
