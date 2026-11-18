# frozen_string_literal: true

module Retrieval
  class Search
    MODES = %w[vector hybrid].freeze
    RRF_K = 60

    def initialize(tenant:, embeddings: Embeddings::Client.build)
      @tenant = tenant
      @embeddings = embeddings
    end

    def call(query:, top_k: default_top_k, namespace: nil, mode: "vector")
      k = [ [ top_k.to_i, 1 ].max, max_top_k ].min
      search_mode = normalize_mode(mode)
      scope = Chunk.for_tenant(@tenant).embedded
      scope = scope.in_namespace(namespace) if namespace.present?

      case search_mode
      when "hybrid"
        hybrid_search(scope, query, k)
      else
        vector_search(scope, query, k)
      end
    end

    private

    def normalize_mode(mode)
      value = mode.to_s.presence || "vector"
      return value if MODES.include?(value)

      "vector"
    end

    def vector_search(scope, query, k)
      vector = @embeddings.embed([ query ]).first
      scope.nearest_neighbors(:embedding, vector, distance: "cosine")
           .limit(k)
           .map { |chunk| serialize_chunk(chunk, chunk.neighbor_distance) }
    end

    def hybrid_search(scope, query, k)
      candidate_limit = [ k * 4, max_top_k * 2 ].max
      vector_hits = vector_ranked(scope, query, candidate_limit)
      keyword_hits = keyword_ranked(scope, query, candidate_limit)

      fused = reciprocal_rank_fuse(vector_hits, keyword_hits)
      fused.first(k).map do |chunk_id, rrf_score|
        chunk = Chunk.find(chunk_id)
        serialize_chunk(chunk, rrf_score)
      end
    end

    def vector_ranked(scope, query, limit)
      vector = @embeddings.embed([ query ]).first
      scope.nearest_neighbors(:embedding, vector, distance: "cosine")
           .limit(limit)
           .pluck(:id)
    end

    def keyword_ranked(scope, query, limit)
      tsquery = Chunk.sanitize_sql_array([ "plainto_tsquery('english', ?)", query ])
      scope.where("content_tsv @@ #{tsquery}")
           .order(Arel.sql("ts_rank(content_tsv, #{tsquery}) DESC"))
           .limit(limit)
           .pluck(:id)
    end

    def reciprocal_rank_fuse(*ranked_id_lists)
      scores = Hash.new(0.0)

      ranked_id_lists.each do |ids|
        ids.each_with_index do |id, index|
          scores[id] += 1.0 / (RRF_K + index + 1)
        end
      end

      scores.sort_by { |_id, score| -score }
    end

    def serialize_chunk(chunk, score)
      {
        id: chunk.id,
        document_id: chunk.document_id,
        position: chunk.position,
        content: chunk.content,
        score: score
      }
    end

    def default_top_k
      ENV.fetch("DEFAULT_TOP_K", "5").to_i
    end

    def max_top_k
      ENV.fetch("MAX_TOP_K", "20").to_i
    end
  end
end
