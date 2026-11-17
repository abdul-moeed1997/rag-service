#!/usr/bin/env node
// Retrieve chunks from RAG Service, then ask OpenAI to answer with that context.

const ragBase = process.env.RAG_BASE_URL || "http://localhost:3000";
const ragKey = process.env.RAG_API_KEY;
const openaiKey = process.env.OPENAI_API_KEY;
const query = process.argv[2] || "What does the document say?";

if (!ragKey) throw new Error("Set RAG_API_KEY");
if (!openaiKey) throw new Error("Set OPENAI_API_KEY for generation");

async function postJson(url, headers, body) {
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    throw new Error(`HTTP ${res.status}: ${await res.text()}`);
  }
  return res.json();
}

const retrieval = await postJson(
  `${ragBase}/query`,
  { Authorization: `Bearer ${ragKey}` },
  { query, top_k: 5 },
);

const context = retrieval.chunks.map((c) => c.content).join("\n---\n");
console.log("=== Retrieved context ===");
console.log(context);
console.log();

const completion = await postJson(
  "https://api.openai.com/v1/chat/completions",
  { Authorization: `Bearer ${openaiKey}` },
  {
    model: "gpt-4o-mini",
    messages: [
      {
        role: "system",
        content:
          "Answer using only the provided context. If the context is insufficient, say so.",
      },
      {
        role: "user",
        content: `Context:\n${context}\n\nQuestion: ${query}`,
      },
    ],
  },
);

console.log("=== LLM answer ===");
console.log(completion.choices[0].message.content);
