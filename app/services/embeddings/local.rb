# frozen_string_literal: true

module Embeddings
  # OpenAI-compatible local / self-hosted embeddings (Ollama, TEI, vLLM, etc.).
  class Local < Client
    def initialize(connection: nil)
      @connection = connection
    end

    def embed(texts)
      input = Array(texts)
      return [] if input.empty?

      response = connection.post("/v1/embeddings") do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["Authorization"] = "Bearer #{api_key}" if api_key.present?
        req.body = {
          model: ENV.fetch("LOCAL_EMBEDDING_MODEL", "nomic-embed-text"),
          input: input
        }.to_json
      end

      unless response.success?
        raise "Local embeddings failed (#{response.status}): #{response.body}"
      end

      body = JSON.parse(response.body)
      body.fetch("data").sort_by { |row| row["index"] }.map { |row| row.fetch("embedding") }
    end

    private

    def api_key
      ENV["EMBEDDING_API_KEY"].presence
    end

    def connection
      @connection ||= Faraday.new(url: ENV.fetch("EMBEDDING_BASE_URL"))
    end
  end
end
