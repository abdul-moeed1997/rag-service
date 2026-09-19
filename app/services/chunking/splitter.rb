# frozen_string_literal: true

module Chunking
  class Splitter
    def initialize(size: ENV.fetch("CHUNK_SIZE", "800").to_i, overlap: ENV.fetch("CHUNK_OVERLAP", "100").to_i)
      @size = size
      @overlap = [ overlap, size - 1 ].min
    end

    def call(text)
      normalized = text.to_s.gsub(/\r\n?/, "\n").strip
      return [] if normalized.empty?

      chunks = []
      start_idx = 0
      while start_idx < normalized.length
        finish = [ start_idx + @size, normalized.length ].min
        chunks << normalized[start_idx...finish]
        break if finish >= normalized.length

        start_idx = finish - @overlap
      end
      chunks
    end
  end
end
