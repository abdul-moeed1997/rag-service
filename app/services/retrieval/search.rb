# frozen_string_literal: true

module Retrieval
  # Finds the chunks most relevant to a query within one tenant.
  #
  # Owns its own input rules: callers pass raw values and read back what was
  # actually used (`mode`, `top_k`). In every mode a higher `score` is better:
  # cosine similarity for vector, reciprocal-rank-fusion score for hybrid.
  # `min_score` drops weaker hits, so "nothing relevant" can come back empty.
  class Search
    class InvalidInput < ArgumentError; end

    Result = Struct.new(:hits, :mode, :top_k, :min_score, keyword_init: true)

    MODES = %w[vector hybrid].freeze
    DEFAULT_MODE = "vector"
    RRF_K = 60
    MAX_QUERY_CHARS = 4_000

    def initialize(tenant:, embeddings: Embeddings::Client.build)
      @tenant = tenant
      @embeddings = embeddings
    end

    def call(query:, top_k: nil, namespace: nil, mode: nil, min_score: nil)
      text = validate_query(query)
      search_mode = validate_mode(mode)
      k = effective_top_k(top_k)
      threshold = validate_min_score(min_score)

      scope = Chunk.for_tenant(@tenant).embedded.embedded_with(@embeddings.model_id)
      scope = scope.in_namespace(namespace) if namespace.present?

      hits = search_mode == "hybrid" ? hybrid_search(scope, text, k) : vector_search(scope, text, k)
      hits = hits.select { |hit| hit[:score] >= threshold } if threshold
      Result.new(hits: hits, mode: search_mode, top_k: k, min_score: threshold)
    end

    private

    def validate_query(query)
      text = query.to_s.strip
      raise InvalidInput, "query is required" if text.empty?
      raise InvalidInput, "query is too long (max #{MAX_QUERY_CHARS} characters)" if text.length > MAX_QUERY_CHARS

      text
    end

    def validate_mode(mode)
      value = mode.to_s.presence || DEFAULT_MODE
      return value if MODES.include?(value)

      raise InvalidInput, "mode must be one of: #{MODES.join(', ')}"
    end

    def validate_min_score(min_score)
      return if min_score.nil? || min_score.to_s.strip.empty?

      Float(min_score.to_s)
    rescue ArgumentError
      raise InvalidInput, "min_score must be a number"
    end

    def effective_top_k(top_k)
      requested = top_k.presence ? top_k.to_i : default_top_k
      requested.clamp(1, max_top_k)
    end

    def vector_search(scope, query, k)
      nearest(scope, query, k).map do |chunk|
        serialize_chunk(chunk, 1.0 - chunk.neighbor_distance)
      end
    end

    def hybrid_search(scope, query, k)
      candidate_limit = [ k * 4, max_top_k * 2 ].max
      vector_ids = nearest(scope, query, candidate_limit).map(&:id)
      keyword_ids = keyword_ranked(scope, query, candidate_limit)

      fused = reciprocal_rank_fuse(vector_ids, keyword_ids).first(k)
      chunks = scope.where(id: fused.map(&:first)).index_by(&:id)
      fused.filter_map do |chunk_id, rrf_score|
        chunk = chunks[chunk_id]
        serialize_chunk(chunk, rrf_score) if chunk
      end
    end

    def nearest(scope, query, limit)
      vector = @embeddings.embed([ query ]).first
      with_filtered_index_scan do
        scope.nearest_neighbors(:embedding, vector, distance: "cosine").limit(limit).to_a
      end
    end

    # An HNSW index returns its nearest rows first and applies the tenant and
    # namespace filters afterwards, which can leave a small tenant with too few
    # results. Iterative scan (pgvector >= 0.8) keeps scanning until `limit`
    # rows pass the filters.
    def with_filtered_index_scan
      return yield unless self.class.iterative_scan_supported?

      Chunk.transaction do
        Chunk.connection.execute("SET LOCAL hnsw.iterative_scan = 'strict_order'")
        yield
      end
    end

    def self.iterative_scan_supported?
      return @iterative_scan_supported if defined?(@iterative_scan_supported)

      version = Chunk.connection.select_value("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
      @iterative_scan_supported = version.present? && Gem::Version.new(version) >= Gem::Version.new("0.8.0")
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
