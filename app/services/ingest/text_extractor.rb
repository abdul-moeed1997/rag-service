# frozen_string_literal: true

require "pdf-reader"
require "nokogiri"

module Ingest
  class TextExtractor
    class UnsupportedType < StandardError; end
    class EmptyText < StandardError; end

    TEXT_EXTENSIONS = %w[.txt .md .csv].freeze
    HTML_EXTENSIONS = %w[.html .htm].freeze
    PDF_CONTENT_TYPES = %w[application/pdf application/x-pdf].freeze
    HTML_CONTENT_TYPES = %w[text/html application/xhtml+xml].freeze
    # Never visible text. `.mermaid` holds diagram source that the browser replaces with a drawing.
    HTML_HIDDEN = "script, style, noscript, template, svg, .mermaid"
    # Elements a browser puts on their own line. Their text must not run into a neighbour's.
    HTML_BLOCK_TAGS = %w[
      address article aside blockquote br dd details div dl dt fieldset figcaption figure footer form
      h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section summary table tbody td tfoot th thead tr ul
    ].to_set.freeze

    def self.supported?(content_type, filename)
      pdf?(content_type, filename) || html?(content_type, filename) || text?(content_type, filename)
    end

    def self.pdf?(content_type, filename)
      PDF_CONTENT_TYPES.include?(content_type.to_s) || File.extname(filename.to_s).downcase == ".pdf"
    end

    def self.html?(content_type, filename)
      HTML_CONTENT_TYPES.include?(content_type.to_s) ||
        HTML_EXTENSIONS.include?(File.extname(filename.to_s).downcase)
    end

    def self.text?(content_type, filename)
      return false if html?(content_type, filename)

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
        elsif self.class.html?(content_type, filename)
          extract_html(io)
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

    def extract_html(io)
      raw = read_text(io)
      doc = Nokogiri::HTML(raw)
      doc.css(HTML_HIDDEN).remove
      root = doc.at("body") || doc
      separate_elements(doc, root)

      root.text.to_s
          .gsub(/[ \t\u00A0]+/, " ")
          .gsub(/ ?\n ?/, "\n")
          .gsub(/\n{3,}/, "\n\n")
          .strip
    end

    # Nokogiri's #text joins the text of neighbouring elements with nothing in
    # between ("<li>one</li><li>two</li>" => "onetwo"). Put a line break around
    # block elements and a space between back-to-back inline elements, so words
    # stay whole and paragraphs stay apart.
    def separate_elements(doc, root)
      root.css("*").each do |node|
        if HTML_BLOCK_TAGS.include?(node.name)
          node.add_previous_sibling(Nokogiri::XML::Text.new("\n", doc))
          node.add_next_sibling(Nokogiri::XML::Text.new("\n", doc))
        elsif node.next_sibling&.element?
          node.add_next_sibling(Nokogiri::XML::Text.new(" ", doc))
        end
      end
    end

    def read_text(io)
      io.read.to_s.force_encoding(Encoding::UTF_8).scrub
    end
  end
end
