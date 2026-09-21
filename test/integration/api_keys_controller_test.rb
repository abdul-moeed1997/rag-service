# frozen_string_literal: true

require "test_helper"

class ApiKeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @operator_key = "test-operator-secret"
    ENV["OPERATOR_API_KEY"] = @operator_key
  end

  teardown do
    ENV.delete("OPERATOR_API_KEY")
  end

  test "creates a tenant and returns the raw token once" do
    assert_difference([ "Tenant.count", "ApiKey.count" ], 1) do
      post "/api_keys",
           params: { api_key: { name: "default", tenant_name: "Acme" } },
           headers: operator_headers,
           as: :json
    end

    assert_response :created
    body = response.parsed_body.fetch("api_key")
    assert_equal "default", body["name"]
    assert_equal "Acme", body["tenant_name"]
    assert body["token"].start_with?("rag_")
    assert_equal body["token"][0, 12], body["token_prefix"]

    key = ApiKey.find(body["id"])
    assert_nil key.raw_token
    assert_equal ApiKey.digest(body["token"]), key.token_digest
  end

  test "mints an additional key for an existing tenant" do
    tenant = Tenant.create!(name: "Existing")
    ApiKey.generate_for!(tenant: tenant, name: "first")

    assert_no_difference("Tenant.count") do
      assert_difference("ApiKey.count", 1) do
        post "/api_keys",
             params: { api_key: { name: "second", tenant_id: tenant.id } },
             headers: operator_headers,
             as: :json
      end
    end

    assert_response :created
    assert_equal tenant.id, response.parsed_body.dig("api_key", "tenant_id")
    assert_equal "second", response.parsed_body.dig("api_key", "name")
  end

  test "rejects missing operator key" do
    post "/api_keys",
         params: { api_key: { name: "default", tenant_name: "Acme" } },
         as: :json

    assert_response :unauthorized
  end

  test "rejects wrong operator key" do
    post "/api_keys",
         params: { api_key: { name: "default", tenant_name: "Acme" } },
         headers: { "Authorization" => "Bearer wrong-key" },
         as: :json

    assert_response :unauthorized
  end

  test "rejects blank name" do
    post "/api_keys",
         params: { api_key: { name: " ", tenant_name: "Acme" } },
         headers: operator_headers,
         as: :json

    assert_response :unprocessable_entity
    assert_match(/name is required/, response.parsed_body["message"])
  end

  test "rejects request without tenant_id or tenant_name" do
    post "/api_keys",
         params: { api_key: { name: "default" } },
         headers: operator_headers,
         as: :json

    assert_response :unprocessable_entity
    assert_match(/tenant_id or tenant_name/, response.parsed_body["message"])
  end

  test "minted key can authenticate document requests" do
    post "/api_keys",
         params: { api_key: { name: "live", tenant_name: "LiveTenant" } },
         headers: operator_headers,
         as: :json
    token = response.parsed_body.dig("api_key", "token")

    post "/documents",
         params: { document: { title: "Notes", content: "hello world", source_type: "text" } },
         headers: { "Authorization" => "Bearer #{token}" },
         as: :json

    assert_response :accepted
  end

  private

  def operator_headers
    { "Authorization" => "Bearer #{@operator_key}" }
  end
end
