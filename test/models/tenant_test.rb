# frozen_string_literal: true

require "test_helper"

class TenantTest < ActiveSupport::TestCase
  test "webhook secret is encrypted at rest and readable through the model" do
    tenant = Tenant.create!(name: "Enc", webhook_url: "https://hooks.example.com/x", webhook_secret: "super-secret")

    stored = Tenant.connection.select_value("SELECT webhook_secret FROM tenants WHERE id = #{tenant.id}")
    assert_not_includes stored, "super-secret"
    assert_equal "super-secret", Tenant.find(tenant.id).webhook_secret
  end

  test "secrets stored before encryption stay readable" do
    tenant = Tenant.create!(name: "Legacy")
    Tenant.connection.execute("UPDATE tenants SET webhook_secret = 'plain-old' WHERE id = #{tenant.id}")

    assert_equal "plain-old", Tenant.find(tenant.id).webhook_secret
  end

  test "rejects webhook URLs that point at internal addresses" do
    %w[http://127.0.0.1/x http://localhost:3000/x http://169.254.169.254/x http://10.0.0.4/hook].each do |url|
      tenant = Tenant.new(name: "Bad", webhook_url: url)
      assert_not tenant.valid?, url
      assert_includes tenant.errors[:webhook_url].join, "private or loopback"
    end
  end

  test "accepts a public webhook URL" do
    assert Tenant.new(name: "Good", webhook_url: "https://hooks.example.com/x").valid?
  end
end
