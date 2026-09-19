# frozen_string_literal: true

class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :title
      t.string :source_type, null: false, default: "text"
      t.text :content
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.timestamps
    end

    add_index :documents, [ :tenant_id, :status ]
  end
end
