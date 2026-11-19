# frozen_string_literal: true

require "test_helper"

class Embeddings::HttpTest < ActiveSupport::TestCase
  test "openai posts to the embeddings endpoint and returns ordered vectors" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") do |env|
        body = JSON.parse(env.body)
        assert_equal "text-embedding-3-small", body["model"]
        assert_equal [ "a", "b" ], body["input"]
        assert_equal "Bearer test-openai-key", env.request_headers["Authorization"]
        ok(data: [ { index: 1, embedding: [ 2.0 ] }, { index: 0, embedding: [ 1.0 ] } ])
      end
    end

    with_env("OPENAI_API_KEY" => "test-openai-key") do
      assert_equal [ [ 1.0 ], [ 2.0 ] ], Embeddings::Openai.new(connection: connection(stubs)).embed([ "a", "b" ])
    end
    stubs.verify_stubbed_calls
  end

  test "splits large inputs into batches and keeps input order" do
    requests = []
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") do |env|
        input = JSON.parse(env.body)["input"]
        requests << input
        ok(data: input.each_with_index.map { |text, index| { index: index, embedding: [ text.to_f ] } })
      end
    end

    with_env("OPENAI_API_KEY" => "k", "EMBEDDING_BATCH_SIZE" => "2") do
      vectors = Embeddings::Openai.new(connection: connection(stubs)).embed(%w[1 2 3 4 5])
      assert_equal [ [ 1.0 ], [ 2.0 ], [ 3.0 ], [ 4.0 ], [ 5.0 ] ], vectors
    end
    assert_equal [ %w[1 2], %w[3 4], %w[5] ], requests
  end

  test "429 and 5xx are transient errors" do
    [ 429, 500, 503 ].each do |status|
      error = assert_raises(Embeddings::TransientError) { embed_with_status(status) }
      assert_match(/\(#{status}\)/, error.message)
    end
  end

  test "other failures are permanent errors" do
    [ 400, 401, 404 ].each do |status|
      error = assert_raises(Embeddings::Error) { embed_with_status(status) }
      assert_not_kind_of Embeddings::TransientError, error
    end
  end

  test "timeouts and connection failures are transient errors" do
    [ Faraday::TimeoutError, Faraday::ConnectionFailed ].each do |failure|
      stubs = Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/v1/embeddings") { raise failure, "boom" }
      end

      with_env("OPENAI_API_KEY" => "k") do
        assert_raises(Embeddings::TransientError) { Embeddings::Openai.new(connection: connection(stubs)).embed([ "a" ]) }
      end
    end
  end

  test "a response with the wrong number of vectors is an error" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") { ok(data: [ { index: 0, embedding: [ 1.0 ] } ]) }
    end

    with_env("OPENAI_API_KEY" => "k") do
      assert_raises(Embeddings::Error) { Embeddings::Openai.new(connection: connection(stubs)).embed([ "a", "b" ]) }
    end
  end

  test "long provider error bodies are truncated" do
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") { [ 400, {}, "x" * 5_000 ] }
    end

    with_env("OPENAI_API_KEY" => "k") do
      error = assert_raises(Embeddings::Error) { Embeddings::Openai.new(connection: connection(stubs)).embed([ "a" ]) }
      assert_operator error.message.length, :<, 500
    end
  end

  test "model_id names the provider, model, and dimensions" do
    with_env("EMBEDDING_DIMENSIONS" => "1536", "VOYAGE_EMBEDDING_MODEL" => "voyage-3") do
      assert_equal "voyage:voyage-3:1536", Embeddings::Voyage.new.model_id
      assert_equal "fake:sha256:1536", Embeddings::Fake.new.model_id
    end
  end

  test "default connection sets timeouts" do
    with_env("OPENAI_API_KEY" => "k") do
      options = Embeddings::Openai.new.send(:connection).options
      assert_equal 5, options.open_timeout
      assert_equal 30, options.timeout
    end
  end

  private

  def embed_with_status(status)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/v1/embeddings") { [ status, {}, "nope" ] }
    end
    with_env("OPENAI_API_KEY" => "k") { Embeddings::Openai.new(connection: connection(stubs)).embed([ "a" ]) }
  end

  def ok(payload)
    [ 200, { "Content-Type" => "application/json" }, payload.to_json ]
  end

  def connection(stubs)
    Faraday.new(url: "https://api.openai.com") { |f| f.adapter :test, stubs }
  end

  def with_env(vars)
    previous = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end
end
