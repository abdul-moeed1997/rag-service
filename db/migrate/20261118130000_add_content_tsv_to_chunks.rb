# frozen_string_literal: true

class AddContentTsvToChunks < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE chunks
      ADD COLUMN content_tsv tsvector
      GENERATED ALWAYS AS (to_tsvector('english', coalesce(content, ''))) STORED
    SQL

    add_index :chunks, :content_tsv, using: :gin
  end

  def down
    remove_index :chunks, :content_tsv
    remove_column :chunks, :content_tsv
  end
end
