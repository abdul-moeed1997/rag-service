#!/usr/bin/env bash
# Retrieve chunks from RAG Service, then ask OpenAI to answer with that context.
set -euo pipefail

: "${RAG_BASE_URL:=http://localhost:3000}"
: "${RAG_API_KEY:?Set RAG_API_KEY}"
: "${OPENAI_API_KEY:?Set OPENAI_API_KEY for generation}"
QUERY="${1:-What does the document say?}"

CHUNKS_JSON=$(curl -sf -X POST "$RAG_BASE_URL/query" \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"query\":$(jq -n --arg q "$QUERY" '$q'),\"top_k\":5}")

CONTEXT=$(echo "$CHUNKS_JSON" | jq -r '[.chunks[].content] | join("\n---\n")')

echo "=== Retrieved context ==="
echo "$CONTEXT"
echo

PAYLOAD=$(jq -n \
  --arg q "$QUERY" \
  --arg ctx "$CONTEXT" \
  '{
    model: "gpt-4o-mini",
    messages: [
      {role: "system", content: "Answer using only the provided context. If the context is insufficient, say so."},
      {role: "user", content: ("Context:\n" + $ctx + "\n\nQuestion: " + $q)}
    ]
  }')

echo "=== LLM answer ==="
curl -sf https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" | jq -r '.choices[0].message.content'
