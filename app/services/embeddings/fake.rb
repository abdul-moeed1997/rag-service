# frozen_string_literal: true

require "digest"

module Embeddings
  # Deterministic vectors with no semantic meaning. For tests and local demos only.
  class Fake < Client
    def provider_name = "fake"
    def model = "sha256"

    def embed(texts)
      Array(texts).map { |text| vector_for(text) }
    end

    private

    def vector_for(text)
      seed = Digest::SHA256.digest(text.to_s)
      dims = dimensions
      Array.new(dims) do |i|
        byte = seed.getbyte(i % seed.bytesize)
        ((byte / 255.0) * 2) - 1
      end
    end
  end
end
