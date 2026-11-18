# frozen_string_literal: true

require "test_helper"

class Embeddings::ClientTest < ActiveSupport::TestCase
  test "build returns fake by default in tests" do
    assert_instance_of Embeddings::Fake, Embeddings::Client.build
  end

  test "build returns voyage when configured" do
    with_env("EMBEDDING_PROVIDER" => "voyage") do
      assert_instance_of Embeddings::Voyage, Embeddings::Client.build
    end
  end

  test "build returns local when configured" do
    with_env("EMBEDDING_PROVIDER" => "local") do
      assert_instance_of Embeddings::Local, Embeddings::Client.build
    end
  end

  test "build raises for unknown provider" do
    with_env("EMBEDDING_PROVIDER" => "nope") do
      assert_raises(ArgumentError) { Embeddings::Client.build }
    end
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
