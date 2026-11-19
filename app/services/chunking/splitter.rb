# frozen_string_literal: true

module Chunking
  # Splits text into overlapping chunks of at most `size` characters.
  # Prefers to end a chunk at a paragraph, then a sentence, then a line,
  # then a word, and only cuts mid-word when there is no whitespace at all.
  class Splitter
    PARAGRAPH = /\n{2,}/
    SENTENCE = /[.!?]["')\]]*\s+/
    LINE = /\n/
    WORD = /\s+/
    BOUNDARIES = [ PARAGRAPH, SENTENCE, LINE, WORD ].freeze
    OVERLAP_START = Regexp.union(PARAGRAPH, SENTENCE)

    def initialize(size: ENV.fetch("CHUNK_SIZE", "800").to_i, overlap: ENV.fetch("CHUNK_OVERLAP", "100").to_i)
      @size = [ size, 1 ].max
      # More than half the window as overlap would mostly re-emit the same text.
      @overlap = overlap.clamp(0, @size / 2)
    end

    def call(text)
      normalized = text.to_s.gsub(/\r\n?/, "\n").strip
      return [] if normalized.empty?

      chunks = []
      start_idx = 0
      while start_idx < normalized.length
        finish = chunk_end(normalized, start_idx)
        piece = normalized[start_idx...finish].strip
        chunks << piece unless piece.empty?
        break if finish >= normalized.length

        start_idx = [ next_start(normalized, finish), start_idx + 1 ].max
      end
      chunks
    end

    private

    def chunk_end(text, start_idx)
      hard_end = start_idx + @size
      return text.length if hard_end >= text.length

      # Never shrink a chunk below half the window just to find a nicer break.
      earliest = start_idx + (@size / 2)
      window = text[earliest...hard_end]

      BOUNDARIES.each do |pattern|
        offset = last_match_end(window, pattern)
        return earliest + offset if offset
      end

      hard_end
    end

    def last_match_end(window, pattern)
      last = nil
      window.scan(pattern) { last = Regexp.last_match.end(0) }
      last
    end

    # Step back by the overlap, then forward to the start of a sentence if one
    # begins inside the overlap, otherwise to the start of a word.
    def next_start(text, finish)
      candidate = finish - @overlap
      return finish if candidate >= finish

      region = text[candidate...finish]
      sentence = region.match(OVERLAP_START)
      return candidate + sentence.end(0) if sentence && sentence.end(0) < region.length
      return candidate if candidate.zero? || text[candidate - 1].match?(/\s/)

      gap = region =~ /\s/
      gap ? candidate + gap + 1 : finish
    end
  end
end
