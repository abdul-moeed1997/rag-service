# frozen_string_literal: true

require "test_helper"

class IngestWebhookTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(
      name: "Hook Tenant",
      webhook_url: "https://hooks.example.com/rag",
      webhook_secret: "hook-secret"
    )
    @key = ApiKey.generate_for!(tenant: @tenant, name: "hook-key")
    @delivered = []

    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("https://hooks.example.com/rag") do |env|
        @delivered << JSON.parse(env.body)
        [ 200, {}, "{}" ]
      end
    end

    Webhooks::IngestStatus.connection_builder = -> { Faraday.new { |f| f.adapter(:test, stubs) } }
  end

  teardown do
    Webhooks::IngestStatus.reset_connection_builder!
  end

  test "delivers ready webhook after successful ingest" do
    perform_enqueued_jobs do
      post "/documents",
           params: { document: { title: "Notes", content: "webhook pineapple text", source_type: "text" } },
           headers: auth_for(@key),
           as: :json
      assert_response :accepted
    end

    assert_equal 1, @delivered.size
    assert_equal "document.ingest.ready", @delivered.first["event"]
    assert_equal "ready", @delivered.first["status"]
  end
end
