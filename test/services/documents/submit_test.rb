# frozen_string_literal: true

require "test_helper"

class Documents::SubmitTest < ActiveSupport::TestCase
  # Simulates losing a race: the lookup misses, then the insert hits the unique index.
  class RacingSubmit < Documents::Submit
    private

    def find_replay
      @lookups = @lookups.to_i + 1
      @lookups == 1 ? nil : super
    end
  end

  setup do
    @tenant = Tenant.create!(name: "Submit")
  end

  test "creates a pending document and queues ingest" do
    result = nil
    assert_enqueued_jobs 1, only: IngestDocumentJob do
      result = Documents::Submit.call(tenant: @tenant, attributes: { title: "T", content: "body" })
    end

    assert_not result.replayed?
    assert_equal "pending", result.document.status
    assert_equal "default", result.document.namespace
    assert_equal "text", result.document.source_type
  end

  test "replays the original document when a concurrent request wins the insert" do
    original = Documents::Submit.call(
      tenant: @tenant, attributes: { title: "T", content: "body" }, idempotency_key: "dup"
    ).document

    result = nil
    assert_no_enqueued_jobs only: IngestDocumentJob do
      result = RacingSubmit.call(tenant: @tenant, attributes: { title: "T", content: "body" }, idempotency_key: "dup")
    end

    assert result.replayed?
    assert_equal original.id, result.document.id
    assert_equal 1, @tenant.documents.count
  end

  test "rejects oversized text content" do
    error = assert_raises(ActiveRecord::RecordInvalid) do
      Documents::Submit.call(tenant: @tenant, attributes: { content: "a" * (Document::MAX_CONTENT_BYTES + 1) })
    end

    assert_match(/too large/, error.message)
  end
end
