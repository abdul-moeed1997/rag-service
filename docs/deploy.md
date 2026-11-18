# Deploying RAG Service

Secrets stay in the environment (never bake them into the image). Minimum required:

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Decrypt credentials / generate secrets |
| `DATABASE_URL` | Postgres + pgvector connection string |
| `SECRET_KEY_BASE` | Optional if master key provides it |
| `OPERATOR_API_KEY` | Mint tenant API keys via `POST /api_keys` |
| `EMBEDDING_PROVIDER` | `fake`, `openai`, `voyage`, or `local` |
| `OPENAI_API_KEY` | Required when `EMBEDDING_PROVIDER=openai` |
| `VOYAGE_API_KEY` | Required when `EMBEDDING_PROVIDER=voyage` |
| `EMBEDDING_BASE_URL` | Required when `EMBEDDING_PROVIDER=local` (OpenAI-compatible host) |

Optional: `VOYAGE_EMBEDDING_MODEL`, `LOCAL_EMBEDDING_MODEL`, `EMBEDDING_API_KEY` (local), `EMBEDDING_DIMENSIONS` (must match `chunks.embedding` / reindex if changed), `LOG_FORMAT` (`json` default in the image), `RAILS_LOG_LEVEL`, `RATE_LIMIT_*`, chunk/top-k settings from `.env.example`.

## Docker image

```bash
docker build -t rag-service .
docker run --rm -p 80:80 \
  -e RAILS_MASTER_KEY=... \
  -e DATABASE_URL=postgres://... \
  -e OPERATOR_API_KEY=... \
  -e EMBEDDING_PROVIDER=fake \
  rag-service
```

Health: `GET /up` and `GET /health`.

## Kamal

This repo already ships `config/deploy.yml` and `.kamal/`. Typical flow:

1. Set registry + server hosts in `config/deploy.yml`.
2. Put secrets in `.kamal/secrets` (see samples): at least `RAILS_MASTER_KEY`, and any registry password.
3. Ensure accessories (or an external DB) provide Postgres with the `vector` extension.
4. Deploy:

```bash
bin/kamal setup    # first time
bin/kamal deploy
bin/kamal logs -f
```

`SOLID_QUEUE_IN_PUMA=true` runs jobs inside the web process. For heavier ingest, add a dedicated `job` role running `bin/jobs` (commented example in `config/deploy.yml`).

## Render

1. Create a **Web Service** from this repo; set Dockerfile as the build method (or use the native Rails buildpack and point start command at `bin/rails server`).
2. Add a **PostgreSQL** instance. After first boot, enable pgvector:

   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

3. Set env vars from the table above (`DATABASE_URL` is usually injected automatically).
4. Add a **Background Worker** with start command `bin/jobs` if you prefer Solid Queue outside Puma.
5. Point health checks at `/up`.

## After deploy

```bash
# Mint a tenant key (operator)
curl -s -X POST https://YOUR_HOST/api_keys \
  -H "Authorization: Bearer $OPERATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"api_key":{"name":"prod","tenant_name":"Acme"}}'
```

See `examples/` for retrieve → own LLM client samples.
