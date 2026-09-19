# frozen_string_literal: true

class QueriesController < ApplicationController
  def create
    query = params.require(:query).to_s
    if query.blank?
      return render json: { error: "invalid", message: "query is required" }, status: :unprocessable_entity
    end

    top_k = params[:top_k]
    chunks = Retrieval::Search.new(tenant: current_tenant).call(query: query, top_k: top_k || ENV.fetch("DEFAULT_TOP_K", "5"))
    render json: { query: query, chunks: chunks }
  end
end
