# frozen_string_literal: true

module Embeddings
  class Openai < Http
    def provider_name = "openai"
    def model = ENV.fetch("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")

    private

    def base_url = "https://api.openai.com"
    def api_key = ENV.fetch("OPENAI_API_KEY")
  end
end
