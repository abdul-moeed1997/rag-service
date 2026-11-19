# frozen_string_literal: true

require "test_helper"

class Webhooks::UrlGuardTest < ActiveSupport::TestCase
  setup do
    @previous_resolver = Webhooks::UrlGuard.resolver
  end

  teardown do
    Webhooks::UrlGuard.resolver = @previous_resolver
    ENV.delete("WEBHOOK_ALLOW_PRIVATE_HOSTS")
  end

  test "allows a host that resolves to a public address" do
    Webhooks::UrlGuard.resolver = ->(_host) { [ "93.184.216.34" ] }
    assert Webhooks::UrlGuard.allowed?("https://hooks.example.com/ingest")
  end

  test "blocks hosts that resolve to private, loopback, or metadata addresses" do
    %w[127.0.0.1 10.1.2.3 172.16.5.5 192.168.1.10 169.254.169.254 ::1 fd00::1 ::ffff:10.0.0.1].each do |address|
      Webhooks::UrlGuard.resolver = ->(_host) { [ address ] }
      assert_not Webhooks::UrlGuard.allowed?("https://sneaky.example.com/x"), address
    end
  end

  test "blocks when any resolved address is internal" do
    Webhooks::UrlGuard.resolver = ->(_host) { [ "93.184.216.34", "10.0.0.5" ] }
    assert_not Webhooks::UrlGuard.allowed?("https://mixed.example.com/x")
  end

  test "blocks literal internal addresses, localhost, unresolvable hosts, and non-http URLs" do
    Webhooks::UrlGuard.resolver = ->(_host) { [] }

    [
      "http://127.0.0.1:3000/x", "http://[::1]/x", "http://localhost/x", "http://db.internal/x",
      "https://does-not-resolve.example.com/x", "ftp://example.com/x", "not a url", ""
    ].each do |url|
      assert_not Webhooks::UrlGuard.allowed?(url), url
    end
  end

  test "obviously_internal? flags literal addresses without DNS" do
    Webhooks::UrlGuard.resolver = ->(_host) { raise "must not resolve" }

    assert Webhooks::UrlGuard.obviously_internal?("http://169.254.169.254/latest/meta-data")
    assert Webhooks::UrlGuard.obviously_internal?("http://localhost:9200")
    assert_not Webhooks::UrlGuard.obviously_internal?("https://hooks.example.com/x")
  end

  test "private hosts can be allowed for local development" do
    ENV["WEBHOOK_ALLOW_PRIVATE_HOSTS"] = "true"

    assert Webhooks::UrlGuard.allowed?("http://localhost:4000/hook")
    assert_not Webhooks::UrlGuard.obviously_internal?("http://localhost:4000/hook")
  end
end
