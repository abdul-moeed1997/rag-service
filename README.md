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
# or: bin/rails "rag:mint_api_key[Default,default]"
bin/rails server
```

In another terminal (Solid Queue, if not using `bin/dev`):

```bash
bin/jobs
```

## API

All routes except `/health`, `/up`, and `POST /api_keys` require:

`Authorization: Bearer rag_...`

`POST /api_keys` is an operator route. Set `OPERATOR_API_KEY` and pass that value as `Authorization: Bearer …` (or `X-Operator-Key`).

### Mint API key (operator)

Creates (or reuses) a tenant and returns the raw token **once**. Only the digest is stored.

```bash
curl -s -X POST http://localhost:3000/api_keys \
  -H "Authorization: Bearer $OPERATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"api_key":{"name":"default","tenant_name":"Acme","tenant_webhook_url":"https://example.com/hooks/rag","tenant_webhook_secret":"optional-hmac-secret"}}'
```

Or attach a key to an existing tenant with `"tenant_id": 1`. Optional `tenant_webhook_url` / `tenant_webhook_secret` configure ingest status callbacks for that tenant.


CLI equivalent:

```bash
bin/rails "rag:mint_api_key[Acme,default]"
```

### Create document (JSON text)

```bash
curl -s -X POST http://localhost:3000/documents \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: notes-v1" \
  -d '{"document":{"title":"Notes","content":"Your document text here","source_type":"text","namespace":"default"}}'
```

Optional `namespace` (default `default`) isolates documents within a tenant. Pass `Idempotency-Key` to safely retry creates: the first call returns `202` and starts ingest; repeats with the same key return `200` with the original document and do **not** re-enqueue ingest.

### Create document (file upload)

`POST /documents` also accepts `multipart/form-data`. Text (`.txt`, `.md`, `.csv`) and PDF files are extracted during ingest.

```bash
curl -s -X POST http://localhost:3000/documents \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -F "document[title]=Notes" \
  -F "document[file]=@./notes.pdf"
```

### Poll ingest status

Ingest is async. Poll until `status` is `ready` or `failed`:

```bash
curl -s http://localhost:3000/documents/$DOCUMENT_ID \
  -H "Authorization: Bearer $RAG_API_KEY"
```

### List documents (cursor pagination)

```bash
curl -s "http://localhost:3000/documents?limit=20" \
  -H "Authorization: Bearer $RAG_API_KEY"

# Filter by namespace:
curl -s "http://localhost:3000/documents?namespace=support" \
  -H "Authorization: Bearer $RAG_API_KEY"

# Next page:
curl -s "http://localhost:3000/documents?limit=20&after=$NEXT_CURSOR" \
  -H "Authorization: Bearer $RAG_API_KEY"
```

Response includes `pagination.next_cursor`, `pagination.has_more`, and `pagination.limit`.

### Reindex document

Re-chunks and re-embeds an existing document (replaces old chunks):

```bash
curl -s -X POST http://localhost:3000/documents/$DOCUMENT_ID/reindex \
  -H "Authorization: Bearer $RAG_API_KEY"
```

### Query (returns chunks only)

```bash
curl -s -X POST http://localhost:3000/query \
  -H "Authorization: Bearer $RAG_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"What does the doc say?","top_k":5,"namespace":"default","mode":"vector"}'
```

Omit `namespace` to search all namespaces for the tenant. Set `mode` to `hybrid` to fuse keyword full-text search with vector similarity (RRF); default is `vector`. Pass retrieved `chunks` into your own LLM to produce an answer.

## Multi-tenant isolation

Each API key belongs to a tenant. Documents and vector search are always scoped to that tenant. Within a tenant, optional `namespace` further isolates documents and retrieval.

## Rate limiting

Authenticated tenant requests are limited per API key (`RATE_LIMIT_PER_MINUTE`, default 60).
Exceeded limits return `429` with `Retry-After` and `X-RateLimit-*` headers.
Set `RATE_LIMIT_ENABLED=false` to disable.

## Ingest webhooks (optional)

Prefer polling `GET /documents/:id` for status. When a tenant has `webhook_url` set, the service also POSTs on terminal ingest:

```json
{
  "event": "document.ingest.ready",
  "document_id": 1,
  "status": "ready",
  "error_message": null,
  "occurred_at": "2026-11-17T12:00:00Z"
}
```

If `webhook_secret` is set, the body is signed with `X-Rag-Signature: sha256=<hmac_hex>`. Webhook delivery failures are logged and do not change document status.

## OpenAPI

- Spec: [`GET /openapi.yaml`](http://localhost:3000/openapi.yaml) (also in [`docs/openapi.yaml`](docs/openapi.yaml))
- Swagger UI: open [`/api-docs.html`](http://localhost:3000/api-docs.html) while the server is running

## Request IDs & logging

Every response includes `X-Request-Id` (echoed from the request header when provided, otherwise generated).
Production logs default to structured JSON (`LOG_FORMAT=json`); set `LOG_FORMAT=text` for plain lines.

## Client examples

See [`examples/`](examples/) for curl, Ruby, and Node samples that retrieve chunks then call your own LLM.

## Deploy

See [`docs/deploy.md`](docs/deploy.md) for Docker, Kamal, and Render notes. Build with:

```bash
docker build -t rag-service .
```
