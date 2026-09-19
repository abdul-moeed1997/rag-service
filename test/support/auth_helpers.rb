# frozen_string_literal: true

module AuthHelpers
  def create_tenant_key(name)
    tenant = Tenant.create!(name: name)
    key = ApiKey.generate_for!(tenant: tenant, name: "#{name}-key")
    [ tenant, key ]
  end

  def auth_for(key)
    { "Authorization" => "Bearer #{key.raw_token}" }
  end

  def text_upload(content, filename: "notes.txt", content_type: "text/plain")
    uploaded_file(content, filename: filename, content_type: content_type)
  end

  def pdf_upload(content, filename: "notes.pdf")
    uploaded_file(PdfFixture.build(content), filename: filename, content_type: "application/pdf")
  end

  def uploaded_file(content, filename:, content_type:)
    dir = Dir.mktmpdir
    path = File.join(dir, filename)
    File.binwrite(path, content)
    Rack::Test::UploadedFile.new(path, content_type)
  end
end
