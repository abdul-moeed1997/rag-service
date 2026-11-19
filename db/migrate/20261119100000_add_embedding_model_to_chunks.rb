# frozen_string_literal: true

# Records which embedding model produced each vector, so vectors from
# different models are never compared. NULL means "embedded before tracking".
class AddEmbeddingModelToChunks < ActiveRecord::Migration[8.1]
  def change
    add_column :chunks, :embedding_model, :string
  end
end
