# frozen_string_literal: true

module Embeddings
  class Voyage < Client
    BASE_URL = "https://api.voyageai.com"

    def initialize(connection: nil)
      @connection = connection
    end

    def embed(texts)
      input = Array(texts)
      return [] if input.empty?

      response = connection.post("/v1/embeddings") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: ENV.fetch("VOYAGE_EMBEDDING_MODEL", "voyage-3"),
          input: input,
          output_dimension: dimensions
        }.to_json
      end

      unless response.success?
        raise "Voyage embeddings failed (#{response.status}): #{response.body}"
      end

      body = JSON.parse(response.body)
      body.fetch("data").sort_by { |row| row["index"] }.map { |row| row.fetch("embedding") }
    end

    private

    def api_key
      ENV.fetch("VOYAGE_API_KEY")
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL)
    end
  end
end
