# frozen_string_literal: true

module Retrieval
  class Search
    def initialize(tenant:, embeddings: Embeddings::Client.build)
      @tenant = tenant
      @embeddings = embeddings
    end

    def call(query:, top_k: default_top_k)
      k = [[ top_k.to_i, 1 ].max, max_top_k ].min
      vector = @embeddings.embed([ query ]).first

      Chunk.for_tenant(@tenant)
           .embedded
           .nearest_neighbors(:embedding, vector, distance: "cosine")
           .limit(k)
           .map do |chunk|
        {
          id: chunk.id,
          document_id: chunk.document_id,
          position: chunk.position,
          content: chunk.content,
          score: chunk.neighbor_distance
        }
      end
    end

    private

    def default_top_k
      ENV.fetch("DEFAULT_TOP_K", "5").to_i
    end

    def max_top_k
      ENV.fetch("MAX_TOP_K", "20").to_i
    end
  end
end
