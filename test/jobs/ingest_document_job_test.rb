# frozen_string_literal: true

require "test_helper"

class IngestDocumentJobTest < ActiveJob::TestCase
  class FlakyEmbeddings < Embeddings::Fake
    def embed(_texts)
      raise Embeddings::TransientError, "provider timed out"
    end
  end

  class BrokenEmbeddings < Embeddings::Fake
    def embed(_texts)
      raise Embeddings::Error, "bad api key"
    end
  end

  setup do
    tenant = Tenant.create!(name: "Jobs")
    @document = Document.create!(tenant: tenant, title: "Doc", content: "some body text", source_type: "text")
  end

  test "ingests the document" do
    IngestDocumentJob.perform_now(@document.id)

    assert_equal "ready", @document.reload.status
    assert_not_empty @document.chunks
  end

  test "a permanent failure marks the document failed and re-raises" do
    with_embeddings(BrokenEmbeddings.new) do
      assert_raises(Embeddings::Error) { IngestDocumentJob.perform_now(@document.id) }
    end

    @document.reload
    assert_equal "failed", @document.status
    assert_equal "bad api key", @document.error_message
  end

  test "a transient failure retries and leaves the document pending" do
    with_embeddings(FlakyEmbeddings.new) do
      assert_enqueued_with(job: IngestDocumentJob, args: [ @document.id ]) do
        IngestDocumentJob.perform_now(@document.id)
      end
    end

    assert_equal "pending", @document.reload.status
    assert_nil @document.error_message
  end

  test "marks the document failed once transient retries run out" do
    with_embeddings(FlakyEmbeddings.new) do
      perform_enqueued_jobs do
        IngestDocumentJob.perform_later(@document.id)
      end
    end

    @document.reload
    assert_equal "failed", @document.status
    assert_equal "provider timed out", @document.error_message
  end

  test "is discarded when the document no longer exists" do
    assert_nothing_raised { IngestDocumentJob.perform_now(-1) }
  end

  private

  def with_embeddings(client)
    original = Embeddings::Client.method(:build)
    Embeddings::Client.define_singleton_method(:build) { client }
    yield
  ensure
    Embeddings::Client.define_singleton_method(:build, original)
  end
end
