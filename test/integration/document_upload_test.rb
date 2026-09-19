# frozen_string_literal: true

require "test_helper"

class DocumentUploadTest < ActionDispatch::IntegrationTest
  setup do
    _tenant, @key = create_tenant_key("Uploads")
  end

  test "accepts a multipart text file in addition to JSON content" do
    document_id = nil

    perform_enqueued_jobs do
      post "/documents",
           params: { document: { title: "File notes", file: text_upload("file unique papaya facts") } },
           headers: auth_for(@key)
      assert_response :accepted
      body = response.parsed_body.fetch("document")
      document_id = body["id"]
      assert_equal "text", body["source_type"]
      assert_equal "notes.txt", body["filename"]
    end

    get "/documents/#{document_id}", headers: auth_for(@key), as: :json
    assert_equal "ready", response.parsed_body.dig("document", "status")

    post "/query",
         params: { query: "papaya facts", top_k: 3 },
         headers: auth_for(@key),
         as: :json
    chunks = response.parsed_body.fetch("chunks")
    assert(chunks.any? { |chunk| chunk["content"].include?("papaya") })
  end

  test "extracts text from an uploaded PDF and makes it queryable" do
    document_id = nil

    perform_enqueued_jobs do
      post "/documents",
           params: { document: { file: pdf_upload("pdf unique kiwi harvest") } },
           headers: auth_for(@key)
      assert_response :accepted
      body = response.parsed_body.fetch("document")
      document_id = body["id"]
      assert_equal "pdf", body["source_type"]
      assert_equal "notes.pdf", body["filename"]
    end

    get "/documents/#{document_id}", headers: auth_for(@key), as: :json
    assert_equal "ready", response.parsed_body.dig("document", "status")

    post "/query",
         params: { query: "kiwi harvest", top_k: 3 },
         headers: auth_for(@key),
         as: :json
    chunks = response.parsed_body.fetch("chunks")
    assert(chunks.any? { |chunk| chunk["content"].include?("kiwi") })
  end

  test "rejects unsupported file types" do
    post "/documents",
         params: { document: { file: uploaded_file("not-a-document", filename: "photo.png", content_type: "image/png") } },
         headers: auth_for(@key)

    assert_response :unprocessable_entity
    assert_match(/text or PDF/, response.parsed_body["message"])
  end

  test "rejects create without content or file" do
    post "/documents",
         params: { document: { title: "Missing" } },
         headers: auth_for(@key),
         as: :json

    assert_response :unprocessable_entity
    assert_match(/content or file is required/, response.parsed_body["message"])
  end
end
