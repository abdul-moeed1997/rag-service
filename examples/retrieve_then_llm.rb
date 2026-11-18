#!/usr/bin/env ruby
# frozen_string_literal: true

# Retrieve chunks from RAG Service, then ask OpenAI to answer with that context.
require "json"
require "net/http"
require "uri"

rag_base = ENV.fetch("RAG_BASE_URL", "http://localhost:3000")
rag_key = ENV.fetch("RAG_API_KEY")
openai_key = ENV.fetch("OPENAI_API_KEY")
query = ARGV[0] || "What does the document say?"

def post_json(url, headers, body)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == "https"
  request = Net::HTTP::Post.new(uri)
  headers.each { |k, v| request[k] = v }
  request["Content-Type"] = "application/json"
  request.body = JSON.generate(body)
  response = http.request(request)
  raise "HTTP #{response.code}: #{response.body}" unless response.is_a?(Net::HTTPSuccess)

  JSON.parse(response.body)
end

retrieval = post_json(
  "#{rag_base}/query",
  { "Authorization" => "Bearer #{rag_key}" },
  { query: query, top_k: 5 }
)

context = retrieval.fetch("chunks").map { |c| c.fetch("content") }.join("\n---\n")
puts "=== Retrieved context ==="
puts context
puts

completion = post_json(
  "https://api.openai.com/v1/chat/completions",
  { "Authorization" => "Bearer #{openai_key}" },
  {
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "Answer using only the provided context. If the context is insufficient, say so." },
      { role: "user", content: "Context:\n#{context}\n\nQuestion: #{query}" }
    ]
  }
)

puts "=== LLM answer ==="
puts completion.dig("choices", 0, "message", "content")
