# frozen_string_literal: true

module Embeddings
  class Client
    PROVIDERS = %w[openai voyage local fake].freeze

    def self.provider
      ENV.fetch("EMBEDDING_PROVIDER", "fake")
    end

    def self.build
      case provider
      when "openai" then Openai.new
      when "voyage" then Voyage.new
      when "local" then Local.new
      when "fake" then Fake.new
      else
        raise ArgumentError, "Unknown EMBEDDING_PROVIDER: #{provider}"
      end
    end

    # Returns one vector per input text, in input order.
    # Raises Embeddings::TransientError when a retry may succeed, Embeddings::Error otherwise.
    def embed(texts)
      raise NotImplementedError
    end

    def dimensions
      ENV.fetch("EMBEDDING_DIMENSIONS", "1536").to_i
    end

    def provider_name
      raise NotImplementedError
    end

    def model
      raise NotImplementedError
    end

    # Identifies the vector space. Stored on each chunk; search only compares
    # chunks whose vectors came from the same model_id.
    def model_id
      "#{provider_name}:#{model}:#{dimensions}"
    end
  end
end
