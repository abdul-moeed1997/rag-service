# frozen_string_literal: true

require "test_helper"

class Embeddings::VoyageTest < ActiveSupport::TestCase
  test "embed posts to Voyage and returns ordered vectors" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") do |env|
        body = JSON.parse(env.body)
        assert_equal "voyage-3", body["model"]
        assert_equal 1536, body["output_dimension"]
        assert_equal [ "hello", "world" ], body["input"]
        assert_equal "Bearer test-voyage-key", env.request_headers["Authorization"]

        [
          200,
          { "Content-Type" => "application/json" },
          {
            data: [
              { index: 1, embedding: [ 0.2, 0.3 ] },
              { index: 0, embedding: [ 0.0, 0.1 ] }
            ]
          }.to_json
        ]
      end
    end

    connection = Faraday.new(url: "https://api.voyageai.com") do |f|
      f.adapter :test, stubs
    end

    with_env("VOYAGE_API_KEY" => "test-voyage-key", "EMBEDDING_DIMENSIONS" => "1536") do
      vectors = Embeddings::Voyage.new(connection: connection).embed([ "hello", "world" ])
      assert_equal [ [ 0.0, 0.1 ], [ 0.2, 0.3 ] ], vectors
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
