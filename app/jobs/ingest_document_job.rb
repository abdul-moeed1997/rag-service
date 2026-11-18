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

    pieces.each_with_index do |piece, index|
      vector = embeddings.embed([ piece ]).first
      document.chunks.create!(
        tenant_id: document.tenant_id,
        namespace: document.namespace,
        position: index,
        content: piece,
        embedding: vector
      )
    end

    document.update!(status: "ready")
    notify_webhook(document)
  rescue StandardError => e
    document&.update!(status: "failed", error_message: e.message)
    notify_webhook(document) if document
    raise
  end

  private

  def notify_webhook(document)
    Webhooks::IngestStatus.call(document: document)
  end
end
