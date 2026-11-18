# Deploying RAG Service

Secrets stay in the environment (never bake them into the image). Minimum required:

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Decrypt credentials / generate secrets |
| `RAG_SERVICE_DATABASE_PASSWORD` | App DB password (match accessory `POSTGRES_PASSWORD`) |
| `DB_HOST` | Postgres host (`rag_service-db` under Kamal) |
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
  -e DB_HOST=... \
  -e RAG_SERVICE_DATABASE_PASSWORD=... \
  -e OPERATOR_API_KEY=... \
  -e EMBEDDING_PROVIDER=fake \
  rag-service
```

Health: `GET /up` and `GET /health`.

## Kamal (primary path)

This repo ships a production-ready Kamal setup:

- [`config/deploy.yml`](../config/deploy.yml) — GHCR image, kamal-proxy SSL, pgvector accessory
- [`.kamal/secrets`](../.kamal/secrets) — pulls secrets from ENV + `config/master.key`
- [`config/postgres/production.sql`](../config/postgres/production.sql) — enables `vector` + Solid DB databases

### One-time setup

1. **VPS** with Docker + SSH (root or a user in the docker group).
2. Edit `config/deploy.yml`:
   - `servers.web` and `accessories.db.host` → your server IP
   - `proxy.host` → your DNS name (A/AAAA must point at that IP)
3. Create a GitHub token with `write:packages` / `read:packages` for GHCR.
4. Export secrets in your shell (or a password manager):

```bash
export KAMAL_REGISTRY_PASSWORD=ghp_...   # GHCR token
export POSTGRES_PASSWORD='strong-db-password'
export OPERATOR_API_KEY='strong-operator-key'
# Optional when not using fake embeddings:
# export OPENAI_API_KEY=...
# export VOYAGE_API_KEY=...
```

5. Ensure `config/master.key` exists locally (for `RAILS_MASTER_KEY` in `.kamal/secrets`).
6. Boot accessories + app:

```bash
bin/kamal setup    # first time (registry login, accessory, deploy)
bin/kamal deploy   # later releases
bin/kamal logs -f
```

`SOLID_QUEUE_IN_PUMA=true` runs jobs inside the web process. For heavier ingest, uncomment the `job` role in `deploy.yml`.

To switch embeddings after deploy, set `EMBEDDING_PROVIDER` (and keys) in `deploy.yml` `env.clear` / `env.secret`, then `bin/kamal deploy`. Changing dimensions requires a migration + reindex.

### Useful aliases

```bash
bin/kamal console
bin/kamal shell
bin/kamal dbc
```

## Render

1. Create a **Web Service** from this repo; set Dockerfile as the build method (or use the native Rails buildpack and point start command at `bin/rails server`).
2. Add a **PostgreSQL** instance. After first boot, enable pgvector:

   ```sql
   CREATE EXTENSION IF NOT EXISTS vector;
   ```

3. Set env vars from the table above (`DATABASE_URL` is usually injected automatically — map host/password into `DB_HOST` / `RAG_SERVICE_DATABASE_PASSWORD`, or adjust `config/database.yml`).
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
