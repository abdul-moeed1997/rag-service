# frozen_string_literal: true

require "test_helper"

class IngestQueryIsolationTest < ActionDispatch::IntegrationTest
  setup do
    _tenant_a, @key_a = create_tenant_key("Alpha")
    _tenant_b, @key_b = create_tenant_key("Beta")
  end

  test "ingested document becomes ready and query returns its chunks" do
    document_id = nil

    perform_enqueued_jobs do
      post "/documents",
           params: { document: { title: "Notes", content: "Alpha secret pineapple recipe", source_type: "text" } },
           headers: auth_for(@key_a),
           as: :json
      assert_response :accepted
      document_id = response.parsed_body.dig("document", "id")
    end

    get "/documents/#{document_id}", headers: auth_for(@key_a), as: :json
    assert_response :success
    assert_equal "ready", response.parsed_body.dig("document", "status")

    post "/query",
         params: { query: "pineapple recipe", top_k: 3 },
         headers: auth_for(@key_a),
         as: :json
    assert_response :success

    chunks = response.parsed_body.fetch("chunks")
    assert_not_empty chunks
    assert(chunks.any? { |chunk| chunk["content"].include?("pineapple") })
    assert(chunks.all? { |chunk| chunk["document_id"] == document_id })
  end

  test "two API keys never see each other's documents or query chunks" do
    id_a = nil
    id_b = nil

    perform_enqueued_jobs do
      post "/documents",
           params: { document: { title: "A", content: "alpha only widget zebra", source_type: "text" } },
           headers: auth_for(@key_a),
           as: :json
      assert_response :accepted
      id_a = response.parsed_body.dig("document", "id")

      post "/documents",
           params: { document: { title: "B", content: "beta only mango canyon", source_type: "text" } },
           headers: auth_for(@key_b),
           as: :json
      assert_response :accepted
      id_b = response.parsed_body.dig("document", "id")
    end

    get "/documents", headers: auth_for(@key_b), as: :json
    titles = response.parsed_body.fetch("documents").map { |doc| doc["title"] }
    assert_includes titles, "B"
    assert_not_includes titles, "A"

    get "/documents/#{id_a}", headers: auth_for(@key_b), as: :json
    assert_response :not_found

    post "/query",
         params: { query: "widget zebra", top_k: 5 },
         headers: auth_for(@key_b),
         as: :json
    assert_response :success

    chunks = response.parsed_body.fetch("chunks")
    assert(chunks.none? { |chunk| chunk["content"].include?("widget") })
    assert(chunks.none? { |chunk| chunk["document_id"] == id_a })
    assert(chunks.all? { |chunk| chunk["document_id"] == id_b })
  end
end
