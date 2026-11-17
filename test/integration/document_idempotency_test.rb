# frozen_string_literal: true

require "test_helper"

class DocumentIdempotencyTest < ActionDispatch::IntegrationTest
  setup do
    _tenant, @key = create_tenant_key("Idempotent")
  end

  test "same Idempotency-Key replays without creating a second document or job" do
    headers = auth_for(@key).merge("Idempotency-Key" => "client-key-1")
    params = { document: { title: "Notes", content: "hello pineapple", source_type: "text" } }

    assert_enqueued_jobs 1, only: IngestDocumentJob do
      post "/documents", params: params, headers: headers, as: :json
      assert_response :accepted
    end

    first_id = response.parsed_body.dig("document", "id")
    assert_equal "client-key-1", response.parsed_body.dig("document", "idempotency_key")

    assert_no_enqueued_jobs only: IngestDocumentJob do
      post "/documents", params: params, headers: headers, as: :json
      assert_response :ok
    end

    assert_equal first_id, response.parsed_body.dig("document", "id")
    assert_equal 1, Document.for_tenant(@key.tenant).where(idempotency_key: "client-key-1").count
  end

  test "different Idempotency-Keys create separate documents" do
    params = { document: { title: "Notes", content: "body", source_type: "text" } }

    post "/documents",
         params: params,
         headers: auth_for(@key).merge("Idempotency-Key" => "key-a"),
         as: :json
    assert_response :accepted
    id_a = response.parsed_body.dig("document", "id")

    post "/documents",
         params: params,
         headers: auth_for(@key).merge("Idempotency-Key" => "key-b"),
         as: :json
    assert_response :accepted
    id_b = response.parsed_body.dig("document", "id")

    assert_not_equal id_a, id_b
    assert_equal 2, Document.for_tenant(@key.tenant).count
  end

  test "omitting Idempotency-Key always creates a new document" do
    params = { document: { title: "Notes", content: "body", source_type: "text" } }

    2.times do
      post "/documents", params: params, headers: auth_for(@key), as: :json
      assert_response :accepted
    end

    assert_equal 2, Document.for_tenant(@key.tenant).count
  end
end
