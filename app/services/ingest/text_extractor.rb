# frozen_string_literal: true

require "pdf-reader"

module Ingest
  class TextExtractor
    class UnsupportedType < StandardError; end
    class EmptyText < StandardError; end

    TEXT_EXTENSIONS = %w[.txt .md .csv].freeze
    PDF_CONTENT_TYPES = %w[application/pdf application/x-pdf].freeze

    def self.supported?(content_type, filename)
      pdf?(content_type, filename) || text?(content_type, filename)
    end

    def self.pdf?(content_type, filename)
      PDF_CONTENT_TYPES.include?(content_type.to_s) || File.extname(filename.to_s).downcase == ".pdf"
    end

    def self.text?(content_type, filename)
      type = content_type.to_s
      type.start_with?("text/") || TEXT_EXTENSIONS.include?(File.extname(filename.to_s).downcase)
    end

    def call(document)
      text = if document.file.attached?
        extract_attachment(document.file)
      else
        document.content.to_s
      end

      normalized = text.to_s.gsub(/\r\n?/, "\n").strip
      raise EmptyText, "No extractable text" if normalized.empty?

      normalized
    end

    private

    def extract_attachment(blob)
      filename = blob.filename.to_s
      content_type = blob.content_type.to_s

      blob.open do |io|
        if self.class.pdf?(content_type, filename)
          extract_pdf(io)
        elsif self.class.text?(content_type, filename)
          read_text(io)
        else
          raise UnsupportedType, "Unsupported file type: #{content_type.presence || filename}"
        end
      end
    end

    def extract_pdf(io)
      PDF::Reader.new(io).pages.map { |page| page.text.to_s }.join("\n\n")
    end

    def read_text(io)
      io.read.to_s.force_encoding(Encoding::UTF_8).scrub
    end
  end
end
