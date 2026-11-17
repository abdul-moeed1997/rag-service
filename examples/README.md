# Client examples: retrieve → your own LLM

RAG Service returns chunks only. Generation stays in your app.

1. Ingest a document (`POST /documents`).
2. Query chunks (`POST /query`).
3. Send those chunks + the user question to your LLM.

| File | Runtime |
|------|---------|
| `retrieve_then_llm.sh` | curl + OpenAI HTTP |
| `retrieve_then_llm.rb` | Ruby + stdlib/net |
| `retrieve_then_llm.mjs` | Node 18+ fetch |

Required env:

```bash
export RAG_BASE_URL=http://localhost:3000
export RAG_API_KEY=rag_...
export OPENAI_API_KEY=sk-...   # for the generation step only
```
