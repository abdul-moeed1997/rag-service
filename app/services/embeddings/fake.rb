# frozen_string_literal: true

require "digest"

module Embeddings
  class Fake < Client
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
