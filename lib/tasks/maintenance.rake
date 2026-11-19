# frozen_string_literal: true

namespace :rag do
  desc "Encrypt tenant webhook secrets that were stored before encryption was enabled"
  task encrypt_webhook_secrets: :environment do
    count = 0
    Tenant.where.not(webhook_secret: nil).find_each do |tenant|
      tenant.encrypt
      count += 1
    end
    puts "Encrypted webhook secrets for #{count} tenant(s)."
  end

  desc "Re-ingest documents whose chunks were embedded with a different model than the one configured"
  task reindex_stale_embeddings: :environment do
    model_id = Embeddings::Client.build.model_id
    document_ids = Chunk.stale_for(model_id).distinct.pluck(:document_id)

    document_ids.each do |id|
      document = Document.find_by(id: id)
      next unless document&.request_reindex!

      IngestDocumentJob.perform_later(document.id)
    end

    puts "Current embedding model: #{model_id}"
    puts "Queued #{document_ids.size} document(s) for re-ingest."
  end
end
