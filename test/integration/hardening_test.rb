# frozen_string_literal: true

require "test_helper"

class HardeningTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    _tenant, @key = create_tenant_key("Hardening")
    @operator_key = "test-operator-secret"
    ENV["OPERATOR_API_KEY"] = @operator_key
  end

  teardown do
    ENV.delete("OPERATOR_API_KEY")
    ENV.delete("OPERATOR_RATE_LIMIT_PER_MINUTE")
    Rails.cache.clear
  end

  # --- health ---

  test "health reports database status without credentials" do
    get "/health"

    assert_response :success
    assert_equal({ "status" => "ok", "database" => "ok" }, response.parsed_body)
  end

  # --- query ---

  test "query reports the mode and top_k that ran" do
    post "/query", params: { query: "anything", top_k: 500 }, headers: auth_for(@key), as: :json

    assert_response :success
    assert_equal "vector", response.parsed_body["mode"]
    assert_equal 20, response.parsed_body["top_k"]
  end

  test "query rejects an unknown mode" do
    post "/query", params: { query: "anything", mode: "banana" }, headers: auth_for(@key), as: :json

    assert_response :unprocessable_entity
    assert_match(/mode must be one of/, response.parsed_body["message"])
  end

  test "query rejects a missing or blank query" do
    post "/query", params: { query: "  " }, headers: auth_for(@key), as: :json
    assert_response :unprocessable_entity

    post "/query", params: { top_k: 3 }, headers: auth_for(@key), as: :json
    assert_response :unprocessable_entity
  end

  # --- documents ---

  test "rejects oversized text content" do
    post "/documents",
         params: { document: { title: "Big", content: "a" * (Document::MAX_CONTENT_BYTES + 1) } },
         headers: auth_for(@key),
         as: :json

    assert_response :unprocessable_entity
    assert_match(/too large/, response.parsed_body["message"])
  end

  # --- api keys ---

  test "a revoked key is rejected on the next request" do
    get "/documents", headers: auth_for(@key)
    assert_response :success

    delete "/api_keys/#{@key.id}", headers: operator_headers
    assert_response :success
    assert_equal false, response.parsed_body.dig("api_key", "active")
    assert_predicate response.parsed_body.dig("api_key", "revoked_at"), :present?

    get "/documents", headers: auth_for(@key)
    assert_response :unauthorized
  end

  test "operator lists a tenant's keys without exposing tokens" do
    get "/api_keys", params: { tenant_id: @key.tenant_id }, headers: operator_headers

    assert_response :success
    keys = response.parsed_body.fetch("api_keys")
    assert_equal [ @key.id ], keys.map { |key| key["id"] }
    assert_not keys.first.key?("token")
    assert_not keys.first.key?("token_digest")
  end

  test "a tenant key cannot list or revoke keys" do
    get "/api_keys", params: { tenant_id: @key.tenant_id }, headers: auth_for(@key)
    assert_response :unauthorized

    delete "/api_keys/#{@key.id}", headers: auth_for(@key)
    assert_response :unauthorized
    assert @key.reload.active?
  end

  test "mints a key with an expiry and rejects a past expiry" do
    post "/api_keys",
         params: { api_key: { name: "temp", tenant_name: "Acme", expires_at: 1.day.from_now.iso8601 } },
         headers: operator_headers, as: :json
    assert_response :created
    assert_predicate response.parsed_body.dig("api_key", "expires_at"), :present?

    post "/api_keys",
         params: { api_key: { name: "old", tenant_name: "Acme", expires_at: 1.day.ago.iso8601 } },
         headers: operator_headers, as: :json
    assert_response :unprocessable_entity
  end

  test "operator endpoint is rate limited per IP, including failed attempts" do
    ENV["OPERATOR_RATE_LIMIT_PER_MINUTE"] = "2"

    2.times do
      get "/api_keys", params: { tenant_id: @key.tenant_id }, headers: { "Authorization" => "Bearer wrong" }
      assert_response :unauthorized
    end

    get "/api_keys", params: { tenant_id: @key.tenant_id }, headers: operator_headers
    assert_response :too_many_requests
    assert_predicate response.headers["Retry-After"], :present?
  end

  private

  def operator_headers
    { "Authorization" => "Bearer #{@operator_key}" }
  end
end
