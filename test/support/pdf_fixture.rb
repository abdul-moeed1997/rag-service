# frozen_string_literal: true

module PdfFixture
  module_function

  def build(text)
    escaped = text.to_s.gsub("\\", "\\\\").gsub("(", "\\(").gsub(")", "\\)")
    stream = "BT /F1 12 Tf 72 720 Td (#{escaped}) Tj ET\n"

    objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n",
      "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>\nendobj\n",
      "4 0 obj\n<< /Length #{stream.bytesize} >>\nstream\n#{stream}endstream\nendobj\n",
      "5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
    ]

    header = "%PDF-1.4\n"
    body = +""
    offsets = []
    cursor = header.bytesize
    objects.each do |obj|
      offsets << cursor
      body << obj
      cursor += obj.bytesize
    end

    xref = +"xref\n0 6\n0000000000 65535 f \n"
    offsets.each { |offset| xref << format("%010d 00000 n \n", offset) }
    trailer = "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{cursor}\n%%EOF\n"

    header + body + xref + trailer
  end
end
