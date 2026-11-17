# frozen_string_literal: true

require "test_helper"

class DocumentsPaginationReindexTest < ActionDispatch::IntegrationTest
  setup do
    _tenant, @key = create_tenant_key("Docs")
  end

  test "lists documents with cursor pagination" do
    3.times do |i|
      Document.create!(
        tenant: @key.tenant,
        title: "T#{i}",
        content: "content #{i}",
        source_type: "text",
        status: "ready",
        created_at: Time.zone.parse("2026-02-01 09:00:0#{i}")
      )
    end

    get "/documents?limit=2", headers: auth_for(@key)
    assert_response :success

    body = response.parsed_body
    assert_equal 2, body.fetch("documents").size
    assert_equal %w[T2 T1], body["documents"].map { |d| d["title"] }
    assert body.dig("pagination", "has_more")
    cursor = body.dig("pagination", "next_cursor")
    assert_predicate cursor, :present?

    get "/documents?limit=2&after=#{CGI.escape(cursor)}", headers: auth_for(@key)
    assert_response :success
    page2 = response.parsed_body
    assert_equal %w[T0], page2["documents"].map { |d| d["title"] }
    assert_not page2.dig("pagination", "has_more")
  end


  test "reindex re-enqueues ingest and replaces chunks" do
    document_id = nil

    perform_enqueued_jobs do
      post "/documents",
           params: { document: { title: "Notes", content: "original pineapple text", source_type: "text" } },
           headers: auth_for(@key),
           as: :json
      assert_response :accepted
      document_id = response.parsed_body.dig("document", "id")
    end

    doc = Document.find(document_id)
    assert_equal "ready", doc.status
    original_chunk_ids = doc.chunks.pluck(:id)
    assert_not_empty original_chunk_ids

    doc.update!(content: "updated mango content for reindex")

    perform_enqueued_jobs do
      post "/documents/#{document_id}/reindex", headers: auth_for(@key), as: :json
      assert_response :accepted
      assert_equal "pending", response.parsed_body.dig("document", "status")
    end

    doc.reload
    assert_equal "ready", doc.status
    assert_not_empty doc.chunks
    assert_empty(original_chunk_ids & doc.chunks.pluck(:id))
    assert(doc.chunks.any? { |chunk| chunk.content.include?("mango") })
  end

  test "reindex returns conflict while processing" do
    doc = Document.create!(
      tenant: @key.tenant,
      title: "Busy",
      content: "busy doc",
      source_type: "text",
      status: "processing"
    )

    post "/documents/#{doc.id}/reindex", headers: auth_for(@key), as: :json
    assert_response :conflict
    assert_equal "conflict", response.parsed_body["error"]
  end
end
