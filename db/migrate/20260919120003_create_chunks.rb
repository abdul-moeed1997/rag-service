# frozen_string_literal: true

class CreateChunks < ActiveRecord::Migration[8.1]
  def change
    enable_extension "vector" unless extension_enabled?("vector")

    create_table :chunks do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :document, null: false, foreign_key: true
      t.integer :position, null: false
      t.text :content, null: false
      t.vector :embedding, limit: 1536
      t.timestamps
    end

    add_index :chunks, [ :document_id, :position ], unique: true
  end
end
