# frozen_string_literal: true

require "test_helper"

class Ingest::TextExtractorTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "Extractor")
  end

  test "returns raw document content when no file is attached" do
    document = Document.create!(
      tenant: @tenant,
      title: "Notes",
      source_type: "text",
      content: "plain content",
      status: "pending"
    )

    assert_equal "plain content", Ingest::TextExtractor.new.call(document)
  end

  test "extracts text from an attached text file" do
    document = Document.new(tenant: @tenant, source_type: "text", status: "pending")
    document.file.attach(
      io: StringIO.new("file unique papaya facts"),
      filename: "notes.txt",
      content_type: "text/plain"
    )
    document.save!

    assert_equal "file unique papaya facts", Ingest::TextExtractor.new.call(document)
  end

  test "extracts text from an attached PDF" do
    document = Document.new(tenant: @tenant, source_type: "pdf", status: "pending")
    document.file.attach(
      io: StringIO.new(PdfFixture.build("pdf unique kiwi harvest")),
      filename: "notes.pdf",
      content_type: "application/pdf"
    )
    document.save!

    assert_includes Ingest::TextExtractor.new.call(document), "pdf unique kiwi harvest"
  end

  test "extracts visible text from an attached HTML file" do
    html = <<~HTML
      <html><head><style>.x{color:red}</style><script>alert(1)</script></head>
      <body><h1>HTML unique mango grove</h1><p>More detail</p></body></html>
    HTML
    document = Document.new(tenant: @tenant, source_type: "html", status: "pending")
    document.file.attach(
      io: StringIO.new(html),
      filename: "notes.html",
      content_type: "text/html"
    )
    document.save!

    text = Ingest::TextExtractor.new.call(document)
    assert_includes text, "HTML unique mango grove"
    assert_includes text, "More detail"
    refute_includes text, "alert(1)"
    refute_includes text, "color:red"
    refute_includes text, "<h1>"
  end

  test "keeps words from neighbouring HTML elements apart" do
    text = extract_html(<<~HTML)
      <html><body><ul><li>alpha</li><li>beta</li></ul><div>gamma</div><div>delta</div>
      <table><tr><td>one</td><td>two</td></tr></table>
      <p><span>epsilon</span><span>zeta</span></p><h2>Title</h2><p>Body</p></body></html>
    HTML

    words = text.split(/\s+/)
    %w[alpha beta gamma delta one two epsilon zeta Title Body].each { |word| assert_includes words, word }
  end

  test "does not split a word that only changes inline formatting" do
    text = extract_html("<html><body><p>H<sub>2</sub>O and <b>bold</b>ly go, x<sup>2</sup>.</p></body></html>")

    assert_includes text, "H2O"
    assert_includes text, "boldly"
    assert_includes text, "x2."
  end

  test "separates paragraphs with a blank line and keeps inline text on one line" do
    text = extract_html("<html><body><p>First <em>para</em> here.</p><p>Second para.</p></body></html>")

    assert_equal "First para here.\n\nSecond para.", text
  end

  test "drops diagram source and other non-visible HTML content" do
    text = extract_html(<<~HTML)
      <html><body><p>Visible</p><pre class="mermaid">flowchart LR A --> B</pre>
      <svg><text>vector label</text></svg><template><p>hidden template</p></template></body></html>
    HTML

    assert_equal "Visible", text
  end

  test "html? is true for text/html and not treated as plain text" do
    assert Ingest::TextExtractor.html?("text/html", "page.html")
    refute Ingest::TextExtractor.text?("text/html", "page.html")
    assert Ingest::TextExtractor.supported?("text/html", "page.html")
  end

  test "raises when an HTML file has no visible text" do
    assert_raises(Ingest::TextExtractor::EmptyText) do
      extract_html("<html><head><script>var x = 1</script></head><body><svg></svg></body></html>")
    end
  end

  test "raises when there is no extractable text" do
    document = Document.new(
      tenant: @tenant,
      title: "Empty",
      source_type: "text",
      content: "   ",
      status: "pending"
    )

    error = assert_raises(Ingest::TextExtractor::EmptyText) do
      Ingest::TextExtractor.new.call(document)
    end
    assert_match(/No extractable text/, error.message)
  end

  private

  def extract_html(html)
    document = Document.new(tenant: @tenant, source_type: "html", status: "pending")
    document.file.attach(io: StringIO.new(html), filename: "page.html", content_type: "text/html")
    document.save!
    Ingest::TextExtractor.new.call(document)
  end
end
