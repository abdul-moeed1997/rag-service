# frozen_string_literal: true

require "test_helper"

class Retrieval::SearchTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(name: "HybridSearch")
    @document = Document.create!(
      tenant: @tenant,
      title: "Manual",
      source_type: "text",
      content: "placeholder",
      status: "ready",
      namespace: "default"
    )
    @embeddings = Embeddings::Fake.new
  end

  test "vector mode returns nearest neighbors unchanged" do
    exact = create_chunk("exact unique bamboo protocol", position: 0)
    create_chunk("unrelated zebra meadow", position: 1)

    results = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings).call(
      query: "exact unique bamboo protocol",
      top_k: 1,
      mode: "vector"
    ).hits

    assert_equal 1, results.size
    assert_equal exact.id, results.first[:id]
  end

  test "hybrid mode ranks exact keyword matches ahead of unrelated vector neighbors" do
    keyword_chunk = create_chunk(
      "The rare token xylophone42 appears only here among support docs",
      position: 0
    )
    # Same fake-embedding neighborhood as a short query is unlikely; create filler noise.
    5.times do |i|
      create_chunk("noise filler paragraph number #{i} about orchids and meadows", position: i + 1)
    end

    hybrid = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings).call(
      query: "xylophone42",
      top_k: 3,
      mode: "hybrid"
    ).hits

    assert_equal keyword_chunk.id, hybrid.first[:id]
    assert(hybrid.any? { |row| row[:content].include?("xylophone42") })
  end

  test "hybrid mode respects namespace filter" do
    create_chunk("namespace alpha has xylophone42", position: 0, namespace: "alpha")
    other = create_chunk("namespace beta has xylophone42", position: 1, namespace: "beta")

    results = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings).call(
      query: "xylophone42",
      top_k: 5,
      mode: "hybrid",
      namespace: "beta"
    ).hits

    assert(results.all? { |row| row[:id] == other.id || Chunk.find(row[:id]).namespace == "beta" })
    assert(results.none? { |row| Chunk.find(row[:id]).namespace == "alpha" })
  end

  test "reports the mode and top_k that were actually used" do
    create_chunk("anything at all", position: 0)
    search = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings)

    defaults = search.call(query: "anything")
    assert_equal "vector", defaults.mode
    assert_equal 5, defaults.top_k

    clamped = search.call(query: "anything", top_k: 9_999, mode: "hybrid")
    assert_equal "hybrid", clamped.mode
    assert_equal 20, clamped.top_k
  end

  test "rejects an unknown mode instead of silently falling back" do
    search = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings)

    error = assert_raises(Retrieval::Search::InvalidInput) { search.call(query: "x", mode: "banana") }
    assert_match(/mode must be one of/, error.message)
  end

  test "rejects blank and oversized queries" do
    search = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings)

    assert_raises(Retrieval::Search::InvalidInput) { search.call(query: "   ") }
    assert_raises(Retrieval::Search::InvalidInput) do
      search.call(query: "x" * (Retrieval::Search::MAX_QUERY_CHARS + 1))
    end
  end

  test "a higher score is better in both modes" do
    exact = create_chunk("exact unique bamboo protocol", position: 0)
    create_chunk("unrelated zebra meadow", position: 1)
    search = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings)

    %w[vector hybrid].each do |mode|
      hits = search.call(query: "exact unique bamboo protocol", top_k: 2, mode: mode).hits
      assert_equal exact.id, hits.first[:id], mode
      assert_operator hits.first[:score], :>, hits.last[:score], mode
    end

    vector_top = search.call(query: "exact unique bamboo protocol", top_k: 1).hits.first
    assert_in_delta 1.0, vector_top[:score], 0.0001
  end

  test "ignores chunks embedded with a different model" do
    current = create_chunk("shared pineapple phrase", position: 0)
    create_chunk("shared pineapple phrase", position: 1, embedding_model: "other:model:1536")
    legacy = create_chunk("shared pineapple phrase", position: 2, embedding_model: nil)
    search = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings)

    %w[vector hybrid].each do |mode|
      ids = search.call(query: "shared pineapple phrase", top_k: 10, mode: mode).hits.map { |hit| hit[:id] }
      assert_equal [ current.id, legacy.id ].sort, ids.sort, mode
    end
  end

  test "never returns another tenant's chunks" do
    other_tenant = Tenant.create!(name: "Other")
    other_document = Document.create!(tenant: other_tenant, title: "X", content: "x", source_type: "text", status: "ready")
    Chunk.create!(
      tenant: other_tenant, document: other_document, namespace: "default", position: 0,
      content: "exact unique bamboo protocol", embedding: @embeddings.embed([ "exact unique bamboo protocol" ]).first
    )
    mine = create_chunk("exact unique bamboo protocol", position: 0)
    search = Retrieval::Search.new(tenant: @tenant, embeddings: @embeddings)

    %w[vector hybrid].each do |mode|
      ids = search.call(query: "exact unique bamboo protocol", top_k: 10, mode: mode).hits.map { |hit| hit[:id] }
      assert_equal [ mine.id ], ids, mode
    end
  end

  private

  def create_chunk(content, position:, namespace: "default", embedding_model: @embeddings.model_id)
    vector = @embeddings.embed([ content ]).first
    Chunk.create!(
      tenant: @tenant,
      document: @document,
      namespace: namespace,
      position: position,
      content: content,
      embedding: vector,
      embedding_model: embedding_model
    )
  end
end
