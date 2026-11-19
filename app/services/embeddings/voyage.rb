# frozen_string_literal: true

module Embeddings
  class Voyage < Http
    def provider_name = "voyage"
    def model = ENV.fetch("VOYAGE_EMBEDDING_MODEL", "voyage-3")

    private

    def base_url = "https://api.voyageai.com"
    def api_key = ENV.fetch("VOYAGE_API_KEY")
    def extra_body = { output_dimension: dimensions }
  end
end
