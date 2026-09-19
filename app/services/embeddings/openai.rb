# frozen_string_literal: true

module Embeddings
  class Openai < Client
    API_URL = "https://api.openai.com/v1/embeddings"

    def embed(texts)
      input = Array(texts)
      return [] if input.empty?

      response = connection.post(API_URL) do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.headers["Content-Type"] = "application/json"
        req.body = {
          model: ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small"),
          input: input
        }.to_json
      end

      unless response.success?
        raise "OpenAI embeddings failed (#{response.status}): #{response.body}"
      end

      body = JSON.parse(response.body)
      body.fetch("data").sort_by { |row| row["index"] }.map { |row| row.fetch("embedding") }
    end

    private

    def api_key
      ENV.fetch("OPENAI_API_KEY")
    end

    def connection
      @connection ||= Faraday.new
    end
  end
end
