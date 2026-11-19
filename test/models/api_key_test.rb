# frozen_string_literal: true

require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "Keys")
    @key = ApiKey.generate_for!(tenant: @tenant, name: "main")
  end

  test "authenticates an active key" do
    assert_equal @key.id, ApiKey.authenticate(@key.raw_token).id
  end

  test "a revoked key no longer authenticates" do
    @key.revoke!

    assert_nil ApiKey.authenticate(@key.raw_token)
    assert_not @key.active?
  end

  test "an expired key no longer authenticates" do
    @key.update!(expires_at: 1.minute.ago)

    assert_nil ApiKey.authenticate(@key.raw_token)
  end

  test "a key with a future expiry authenticates" do
    @key.update!(expires_at: 1.day.from_now)

    assert_equal @key.id, ApiKey.authenticate(@key.raw_token).id
  end

  test "last_used_at is written at most once per resolution window" do
    freeze_time do
      ApiKey.authenticate(@key.raw_token)
      first = @key.reload.last_used_at
      assert_equal Time.current, first

      travel 1.minute
      ApiKey.authenticate(@key.raw_token)
      assert_equal first, @key.reload.last_used_at

      travel ApiKey::LAST_USED_RESOLUTION
      ApiKey.authenticate(@key.raw_token)
      assert_operator @key.reload.last_used_at, :>, first
    end
  end
end
