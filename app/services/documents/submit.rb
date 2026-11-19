# frozen_string_literal: true

module Documents
  # Accepts a new Document for a tenant and queues it for ingest.
  # With an idempotency key, a repeat submission returns the original document
  # instead of creating a second one, including when two requests race.
  class Submit
    Result = Struct.new(:document, :replayed, keyword_init: true) do
      def replayed?
        replayed
      end
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(tenant:, attributes:, file: nil, idempotency_key: nil)
      @tenant = tenant
      @attributes = attributes.to_h.symbolize_keys
      @file = file
      @idempotency_key = idempotency_key.presence
    end

    def call
      existing = find_replay
      return Result.new(document: existing, replayed: true) if existing

      document = build
      document.save!
      IngestDocumentJob.perform_later(document.id)
      Result.new(document: document, replayed: false)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent request with the same key won the insert.
      existing = find_replay
      raise unless existing

      Result.new(document: existing, replayed: true)
    end

    private

    def find_replay
      return unless @idempotency_key

      Document.for_tenant(@tenant).find_by(idempotency_key: @idempotency_key)
    end

    def build
      document = Document.for_tenant(@tenant).new(@attributes.slice(:title, :content))
      document.file.attach(@file) if @file.present?
      document.source_type = source_type
      document.namespace = @attributes[:namespace].presence || Document::DEFAULT_NAMESPACE
      document.title = document.title.presence || @file&.original_filename
      document.status = Document::PENDING
      document.idempotency_key = @idempotency_key
      document
    end

    def source_type
      if @file.present?
        return "pdf" if Ingest::TextExtractor.pdf?(@file.content_type, @file.original_filename)
        return "html" if Ingest::TextExtractor.html?(@file.content_type, @file.original_filename)
      end

      @attributes[:source_type].presence || "text"
    end
  end
end
