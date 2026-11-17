# frozen_string_literal: true

require "test_helper"

class Webhooks::IngestStatusTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(
      name: "Webhook Co",
      webhook_url: "https://hooks.example.com/ingest",
      webhook_secret: "super-secret"
    )
    @document = Document.create!(
      tenant: @tenant,
      title: "Doc",
      content: "ready body",
      source_type: "text",
      status: "ready"
    )
  end

  teardown do
    Webhooks::IngestStatus.reset_connection_builder!
  end

  test "posts signed payload to tenant webhook_url" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("https://hooks.example.com/ingest") do |env|
        body = env.body
        payload = JSON.parse(body)
        assert_equal "document.ingest.ready", payload["event"]
        assert_equal @document.id, payload["document_id"]
        assert_equal "ready", payload["status"]

        expected = OpenSSL::HMAC.hexdigest("SHA256", "super-secret", body)
        assert_equal "sha256=#{expected}", env.request_headers["X-Rag-Signature"]
        [ 200, { "Content-Type" => "application/json" }, "{}" ]
      end
    end

    Webhooks::IngestStatus.connection_builder = -> { Faraday.new { |f| f.adapter(:test, stubs) } }
    Webhooks::IngestStatus.call(document: @document)
    stubs.verify_stubbed_calls
  end

  test "skips when webhook_url is blank" do
    @tenant.update!(webhook_url: nil)
    called = false
    Webhooks::IngestStatus.connection_builder = -> {
      called = true
      raise "should not connect"
    }
    Webhooks::IngestStatus.call(document: @document)
    assert_not called
  end
end
