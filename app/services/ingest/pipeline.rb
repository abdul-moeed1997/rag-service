# frozen_string_literal: true

module Ingest
  # Turns a Document into searchable Chunks: extract text, split, embed, store.
  #
  # All slow and fallible work (file parsing, the embeddings provider) happens
  # before the database is touched. The old chunks are then replaced by the new
  # ones in one transaction, so a failed run leaves the previous chunks intact.
  #
  # Raises on failure and leaves the status as `processing`; the caller decides
  # whether that failure is final (see IngestDocumentJob).
  class Pipeline
    def self.call(document, **dependencies)
      new(**dependencies).call(document)
    end

    def initialize(extractor: TextExtractor.new, splitter: Chunking::Splitter.new, embeddings: Embeddings::Client.build)
      @extractor = extractor
      @splitter = splitter
      @embeddings = embeddings
    end

    def call(document)
      document.update!(status: Document::PROCESSING, error_message: nil)

      text = @extractor.call(document)
      pieces = @splitter.call(text)
      vectors = @embeddings.embed(pieces)
      unless vectors.size == pieces.size
        raise Embeddings::Error, "Expected #{pieces.size} vectors, got #{vectors.size}"
      end

      replace_chunks(document, text, pieces, vectors)
      document
    end

    private

    def replace_chunks(document, text, pieces, vectors)
      now = Time.current
      model_id = @embeddings.model_id
      rows = pieces.each_with_index.map do |piece, index|
        {
          tenant_id: document.tenant_id,
          document_id: document.id,
          namespace: document.namespace,
          position: index,
          content: piece,
          embedding: vectors[index],
          embedding_model: model_id,
          created_at: now,
          updated_at: now
        }
      end

      Document.transaction do
        document.chunks.delete_all
        Chunk.insert_all!(rows) if rows.any?
        document.update!(content: text, status: Document::READY)
      end
      # delete_all + insert_all bypass the association cache; drop it so callers see the new chunks.
      document.chunks.reset
    end
  end
end
