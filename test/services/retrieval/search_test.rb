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
    )

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
    )

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
    )

    assert(results.all? { |row| row[:id] == other.id || Chunk.find(row[:id]).namespace == "beta" })
    assert(results.none? { |row| Chunk.find(row[:id]).namespace == "alpha" })
  end

  private

  def create_chunk(content, position:, namespace: "default")
    vector = @embeddings.embed([ content ]).first
    Chunk.create!(
      tenant: @tenant,
      document: @document,
      namespace: namespace,
      position: position,
      content: content,
      embedding: vector
    )
  end
end
