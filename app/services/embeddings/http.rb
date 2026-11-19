# frozen_string_literal: true

module Embeddings
  # One request path for every OpenAI-compatible embeddings endpoint.
  # Providers are subclasses that only supply settings.
  class Http < Client
    PATH = "/v1/embeddings"
    ERROR_BODY_LIMIT = 300

    def initialize(connection: nil)
      @connection = connection
    end

    def embed(texts)
      input = Array(texts)
      return [] if input.empty?

      input.each_slice(batch_size).flat_map { |batch| request(batch) }
    end

    private

    # --- provider settings (override in subclasses) ---

    def base_url
      raise NotImplementedError
    end

    def api_key
      nil
    end

    def extra_body
      {}
    end

    # --- shared request path ---

    def request(batch)
      response = connection.post(PATH) do |req|
        req.headers["Content-Type"] = "application/json"
        req.headers["Authorization"] = "Bearer #{api_key}" if api_key.present?
        req.body = { model: model, input: batch }.merge(extra_body).to_json
      end

      raise error_for(response) unless response.success?

      vectors = parse(response.body)
      unless vectors.size == batch.size
        raise Error, "#{label} embeddings returned #{vectors.size} vectors for #{batch.size} inputs"
      end

      vectors
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise TransientError, "#{label} embeddings unreachable: #{e.class.name.demodulize}"
    end

    def parse(body)
      JSON.parse(body).fetch("data").sort_by { |row| row["index"] }.map { |row| row.fetch("embedding") }
    rescue JSON::ParserError, KeyError, TypeError, NoMethodError
      raise Error, "#{label} embeddings returned an unreadable response"
    end

    def error_for(response)
      message = "#{label} embeddings failed (#{response.status}): #{response.body.to_s.truncate(ERROR_BODY_LIMIT)}"
      transient = response.status == 429 || response.status >= 500
      (transient ? TransientError : Error).new(message)
    end

    def label
      provider_name.capitalize
    end

    def batch_size
      [ ENV.fetch("EMBEDDING_BATCH_SIZE", "64").to_i, 1 ].max
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.options.open_timeout = ENV.fetch("EMBEDDING_OPEN_TIMEOUT", "5").to_i
        f.options.timeout = ENV.fetch("EMBEDDING_TIMEOUT", "30").to_i
      end
    end
  end
end
