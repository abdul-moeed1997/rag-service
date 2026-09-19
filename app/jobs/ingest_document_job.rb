# frozen_string_literal: true

class IngestDocumentJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)
    document.update!(status: "processing", error_message: nil)

    text = Ingest::TextExtractor.new.call(document)
    document.update!(content: text)

    splitter = Chunking::Splitter.new
    embeddings = Embeddings::Client.build
    pieces = splitter.call(document.content)

    document.chunks.destroy_all

    pieces.each_with_index do |text, index|
      vector = embeddings.embed([ text ]).first
      document.chunks.create!(
        tenant_id: document.tenant_id,
        position: index,
        content: text,
        embedding: vector
      )
    end

    document.update!(status: "ready")
  rescue StandardError => e
    document&.update!(status: "failed", error_message: e.message)
    raise
  end
end
