# RAG Service

Rails API for document ingest, chunking, embeddings (pgvector), and retrieval.
Clients bring their own LLM for generation.

## Stack

- Ruby 3.4 / Rails 8 API
- PostgreSQL + pgvector (Docker Compose)
- Solid Queue for async ingest
- Embedding providers: `fake` (local) or `openai`

## Quick start

```bash
cp .env.example .env
docker compose up -d
bin/setup
bin/rails db:seed   # prints a one-time API key
bin/rails server
```

In another terminal (Solid Queue, if not using `bin/dev`):

```bash
bin/jobs
```

## API

All routes except `/health` and `/up` require:

`Authorization: Bearer rag_...`

### Create document (JSON text)

```bash
curl -s -X POST http://localhost:3000/documents \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"document":{"title":"Notes","content":"Your document text here","source_type":"text"}}'
```

### Create document (file upload)

`POST /documents` also accepts `multipart/form-data`. Text (`.txt`, `.md`, `.csv`) and PDF files are extracted during ingest.

```bash
curl -s -X POST http://localhost:3000/documents \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -F "document[title]=Notes" \
  -F "document[file]=@./notes.pdf"
```

### Query (returns chunks only)

```bash
curl -s -X POST http://localhost:3000/query \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"What does the doc say?","top_k":5}'
```

Pass retrieved `chunks` into your own LLM to produce an answer.

## Multi-tenant isolation

Each API key belongs to a tenant. Documents and vector search are always scoped to that tenant.
