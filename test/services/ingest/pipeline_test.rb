# frozen_string_literal: true

require "test_helper"

class Ingest::PipelineTest < ActiveSupport::TestCase
  class RecordingEmbeddings < Embeddings::Fake
    attr_reader :calls

    def embed(texts)
      (@calls ||= []) << Array(texts).size
      super
    end
  end

  class FailingEmbeddings < Embeddings::Fake
    def embed(_texts)
      raise Embeddings::Error, "provider said no"
    end
  end

  setup do
    @tenant = Tenant.create!(name: "Pipeline")
    @document = Document.create!(
      tenant: @tenant,
      title: "Guide",
      content: Array.new(120) { |i| "word#{i}" }.join(" "),
      source_type: "text",
      namespace: "manuals"
    )
    @splitter = Chunking::Splitter.new(size: 100, overlap: 10)
  end

  test "stores ordered chunks and marks the document ready" do
    Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: Embeddings::Fake.new)

    @document.reload
    chunks = @document.chunks.order(:position)
    assert_equal "ready", @document.status
    assert_operator chunks.size, :>, 1
    assert_equal (0...chunks.size).to_a, chunks.map(&:position)
    assert(chunks.all? { |chunk| chunk.tenant_id == @tenant.id && chunk.namespace == "manuals" })
    assert(chunks.all? { |chunk| chunk.embedding.present? })
  end

  test "records which embedding model produced the vectors" do
    embeddings = Embeddings::Fake.new
    Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: embeddings)

    assert_equal [ embeddings.model_id ], @document.chunks.distinct.pluck(:embedding_model)
  end

  test "embeds all chunks in one call instead of one call per chunk" do
    embeddings = RecordingEmbeddings.new
    Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: embeddings)

    assert_equal [ @document.chunks.count ], embeddings.calls
  end

  test "a failed run keeps the previous chunks" do
    Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: Embeddings::Fake.new)
    original_ids = @document.chunks.pluck(:id).sort
    assert_not_empty original_ids

    assert_raises(Embeddings::Error) do
      Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: FailingEmbeddings.new)
    end

    assert_equal original_ids, @document.chunks.reload.pluck(:id).sort
  end

  test "a successful rerun replaces the previous chunks" do
    Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: Embeddings::Fake.new)
    original_ids = @document.chunks.pluck(:id)

    @document.update!(content: "short replacement text")
    Ingest::Pipeline.call(@document, splitter: @splitter, embeddings: Embeddings::Fake.new)

    chunks = @document.chunks.reload
    assert_equal [ "short replacement text" ], chunks.map(&:content)
    assert_empty original_ids & chunks.map(&:id)
  end
end
