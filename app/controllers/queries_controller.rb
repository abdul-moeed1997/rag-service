# frozen_string_literal: true

class QueriesController < ApplicationController
  # The default JSON wrapper nests the whole body under "query" (the controller
  # name), which would collide with the real `query` field.
  wrap_parameters false

  def create
    namespace = params[:namespace].presence
    query = params[:query].is_a?(String) ? params[:query] : nil
    result = Retrieval::Search.new(tenant: current_tenant).call(
      query: query,
      top_k: params[:top_k],
      namespace: namespace,
      mode: params[:mode],
      min_score: params[:min_score]
    )

    render json: {
      query: query.strip,
      chunks: result.hits,
      namespace: namespace,
      mode: result.mode,
      top_k: result.top_k,
      min_score: result.min_score
    }
  rescue Retrieval::Search::InvalidInput => e
    render json: { error: "invalid", message: e.message }, status: :unprocessable_entity
  rescue Embeddings::Error => e
    Rails.error.report(e, handled: true, context: { source: "query" })
    render json: { error: "embedding_unavailable", message: "Embedding provider is unavailable. Try again shortly." },
           status: :service_unavailable
  end
end
