# frozen_string_literal: true

require "test_helper"

class ApiKeysMintTest < ActiveSupport::TestCase
  test "finds or creates tenant by name and mints a key" do
    result = ApiKeys::Mint.call(name: "ops", tenant_name: "Ops Co")
    key = result[:api_key]
    tenant = result[:tenant]

    assert_equal "Ops Co", tenant.name
    assert_equal "ops", key.name
    assert key.raw_token.start_with?("rag_")
    assert_equal tenant.id, key.tenant_id
  end

  test "reuses an existing tenant by name" do
    existing = Tenant.create!(name: "Reuse")

    assert_no_difference("Tenant.count") do
      result = ApiKeys::Mint.call(name: "second", tenant_name: "Reuse")
      assert_equal existing.id, result[:tenant].id
    end
  end

  test "raises when name is blank" do
    error = assert_raises(ApiKeys::Mint::Error) do
      ApiKeys::Mint.call(name: " ", tenant_name: "Acme")
    end
    assert_match(/name is required/, error.message)
  end

  test "sets tenant webhook fields when provided" do
    result = ApiKeys::Mint.call(
      name: "ops",
      tenant_name: "Hooked",
      tenant_webhook_url: "https://example.com/hooks",
      tenant_webhook_secret: "s3cret"
    )

    tenant = result[:tenant].reload
    assert_equal "https://example.com/hooks", tenant.webhook_url
    assert_equal "s3cret", tenant.webhook_secret
  end
end
