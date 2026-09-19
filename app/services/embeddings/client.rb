# frozen_string_literal: true

module Embeddings
  class Client
    def self.build
      case ENV.fetch("EMBEDDING_PROVIDER", "fake")
      when "openai" then Openai.new
      when "fake" then Fake.new
      else
        raise ArgumentError, "Unknown EMBEDDING_PROVIDER: #{ENV['EMBEDDING_PROVIDER']}"
      end
    end

    def embed(texts)
      raise NotImplementedError
    end

    def dimensions
      ENV.fetch("EMBEDDING_DIMENSIONS", "1536").to_i
    end
  end
end
