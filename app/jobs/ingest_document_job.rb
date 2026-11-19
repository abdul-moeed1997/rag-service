# frozen_string_literal: true

class IngestDocumentJob < ApplicationJob
  queue_as :default

  # The document was deleted before the job ran.
  discard_on ActiveRecord::RecordNotFound

  # Provider hiccups (timeouts, 429, 5xx): retry with backoff. The document
  # goes back to `pending` between attempts and only fails once retries run out.
  retry_on Embeddings::TransientError, wait: :polynomially_longer, attempts: 4 do |job, error|
    document = Document.find_by(id: job.arguments.first)
    job.fail_document(document, error) if document
  end

  def perform(document_id)
    document = Document.find(document_id)
    Ingest::Pipeline.call(document)
    Webhooks::IngestStatus.call(document: document)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue Embeddings::TransientError
    document.update!(status: Document::PENDING)
    raise
  rescue StandardError => e
    fail_document(document, e)
    raise
  end

  def fail_document(document, error)
    document.update!(status: Document::FAILED, error_message: error.message.to_s.truncate(500))
    Webhooks::IngestStatus.call(document: document)
  end
end
