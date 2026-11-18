# frozen_string_literal: true

require "test_helper"

class RateLimitTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    _tenant, @key = create_tenant_key("Limited")
    @previous_limit = ENV["RATE_LIMIT_PER_MINUTE"]
    @previous_enabled = ENV["RATE_LIMIT_ENABLED"]
    ENV["RATE_LIMIT_ENABLED"] = "true"
    ENV["RATE_LIMIT_PER_MINUTE"] = "2"
  end

  teardown do
    ENV["RATE_LIMIT_PER_MINUTE"] = @previous_limit
    ENV["RATE_LIMIT_ENABLED"] = @previous_enabled
    Rails.cache.clear
  end

  test "returns 429 with headers when per-key limit is exceeded" do
    2.times do
      get "/documents", headers: auth_for(@key), as: :json
      assert_response :success
    end

    get "/documents", headers: auth_for(@key), as: :json
    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body["error"]
    assert_equal "2", response.headers["X-RateLimit-Limit"]
    assert_equal "0", response.headers["X-RateLimit-Remaining"]
    assert_predicate response.headers["Retry-After"], :present?
  end

  test "limits are isolated per API key" do
    _other_tenant, other_key = create_tenant_key("Other")

    2.times do
      get "/documents", headers: auth_for(@key), as: :json
      assert_response :success
    end

    get "/documents", headers: auth_for(@key), as: :json
    assert_response :too_many_requests

    get "/documents", headers: auth_for(other_key), as: :json
    assert_response :success
  end
end
