# frozen_string_literal: true

require "test_helper"

class RateLimit::PerApiKeyTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    _tenant, @key = create_tenant_key("Rate")
    @previous_enabled = ENV["RATE_LIMIT_ENABLED"]
    ENV["RATE_LIMIT_ENABLED"] = "true"
  end

  teardown do
    ENV["RATE_LIMIT_ENABLED"] = @previous_enabled
    Rails.cache.clear
  end

  test "allows requests under the limit and then marks limited" do
    limiter = RateLimit::PerApiKey.new(api_key: @key, limit: 2)

    first = limiter.consume!
    second = limiter.consume!
    third = limiter.consume!

    assert_not first.limited?
    assert_equal 1, first.remaining
    assert_not second.limited?
    assert_equal 0, second.remaining
    assert third.limited?
    assert_equal 0, third.remaining
    assert third.retry_after.positive?
  end

  test "disabled limiter never blocks" do
    ENV["RATE_LIMIT_ENABLED"] = "false"
    limiter = RateLimit::PerApiKey.new(api_key: @key, limit: 1)

    3.times do
      result = limiter.consume!
      assert_not result.limited?
    end
  end
end
