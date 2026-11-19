# frozen_string_literal: true

module Embeddings
  # OpenAI-compatible local / self-hosted embeddings (Ollama, TEI, vLLM, etc.).
  class Local < Http
    def provider_name = "local"
    def model = ENV.fetch("LOCAL_EMBEDDING_MODEL", "nomic-embed-text")

    private

    def base_url = ENV.fetch("EMBEDDING_BASE_URL")
    def api_key = ENV["EMBEDDING_API_KEY"].presence
  end
end
