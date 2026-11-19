# frozen_string_literal: true

module Webhooks
  class IngestStatus
    class << self
      attr_writer :connection_builder

      def connection_builder
        @connection_builder || default_connection_builder
      end

      def reset_connection_builder!
        @connection_builder = nil
      end

      def default_connection_builder
        lambda do
          Faraday.new do |f|
            f.request :url_encoded
            f.adapter Faraday.default_adapter
            f.options.timeout = 5
            f.options.open_timeout = 2
          end
        end
      end

      def call(document:)
        new(document: document).call
      end
    end

    def initialize(document:)
      @document = document
      @tenant = document.tenant
    end

    def call
      return if @tenant.webhook_url.blank?

      unless UrlGuard.allowed?(@tenant.webhook_url)
        Rails.logger.warn("Ingest webhook blocked document_id=#{@document.id} reason=disallowed_host")
        return
      end

      body = JSON.generate(
        event: "document.ingest.#{@document.status}",
        document_id: @document.id,
        status: @document.status,
        error_message: @document.error_message,
        occurred_at: Time.current.utc.iso8601
      )

      headers = { "Content-Type" => "application/json", "User-Agent" => "rag-service-webhooks" }
      if @tenant.webhook_secret.present?
        signature = OpenSSL::HMAC.hexdigest("SHA256", @tenant.webhook_secret, body)
        headers["X-Rag-Signature"] = "sha256=#{signature}"
      end

      response = connection.post(@tenant.webhook_url) do |req|
        req.headers.update(headers)
        req.body = body
      end

      unless response.success?
        Rails.logger.warn("Ingest webhook failed document_id=#{@document.id} status=#{response.status}")
      end
    rescue StandardError => e
      Rails.logger.warn("Ingest webhook error document_id=#{@document.id} error=#{e.class}: #{e.message}")
      Rails.error.report(e, handled: true, context: { document_id: @document.id, source: "ingest_webhook" })
    end

    private

    def connection
      self.class.connection_builder.call
    end
  end
end
