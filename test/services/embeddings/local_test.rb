# frozen_string_literal: true

require "test_helper"

class Embeddings::LocalTest < ActiveSupport::TestCase
  test "embed posts to OpenAI-compatible local endpoint" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") do |env|
        body = JSON.parse(env.body)
        assert_equal "nomic-embed-text", body["model"]
        assert_equal [ "alpha" ], body["input"]
        assert_equal "Bearer local-secret", env.request_headers["Authorization"]

        [
          200,
          { "Content-Type" => "application/json" },
          { data: [ { index: 0, embedding: [ 1.0, 2.0, 3.0 ] } ] }.to_json
        ]
      end
    end

    connection = Faraday.new(url: "http://embeddings.local") do |f|
      f.adapter :test, stubs
    end

    with_env(
      "EMBEDDING_BASE_URL" => "http://embeddings.local",
      "LOCAL_EMBEDDING_MODEL" => "nomic-embed-text",
      "EMBEDDING_API_KEY" => "local-secret"
    ) do
      vectors = Embeddings::Local.new(connection: connection).embed([ "alpha" ])
      assert_equal [ [ 1.0, 2.0, 3.0 ] ], vectors
    end

    stubs.verify_stubbed_calls
  end

  private

  def with_env(vars)
    previous = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
