# Deploying RAG Service

Secrets stay in the environment (never bake them into the image). Minimum required:

| Variable | Purpose |
|----------|---------|
| `RAILS_MASTER_KEY` | Decrypt credentials / generate secrets |
| `RAG_SERVICE_DATABASE_PASSWORD` | App DB password (match accessory `POSTGRES_PASSWORD`) |
| `DB_HOST` | Postgres host (`rag_service-db` under Kamal) |
| `OPERATOR_API_KEY` | Mint tenant API keys via `POST /api_keys` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`, `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | Encrypt tenant webhook secrets. Generate with `bin/rails db:encryption:init`. Losing them makes stored secrets unreadable |
| `EMBEDDING_PROVIDER` | `openai`, `voyage`, or `local`. `fake` is refused in production unless `ALLOW_FAKE_EMBEDDINGS=true` |
| `OPENAI_API_KEY` | Required when `EMBEDDING_PROVIDER=openai` |
| `VOYAGE_API_KEY` | Required when `EMBEDDING_PROVIDER=voyage` |
| `EMBEDDING_BASE_URL` | Required when `EMBEDDING_PROVIDER=local` (OpenAI-compatible host) |

The app checks these at boot in production and refuses to start, with a message naming what is missing, if the embedding provider is `fake`, the provider's key is absent, or the encryption keys are absent.

Optional: `EMBEDDING_BATCH_SIZE`, `EMBEDDING_TIMEOUT`, `EMBEDDING_OPEN_TIMEOUT`, `OPERATOR_RATE_LIMIT_PER_MINUTE`, `WEBHOOK_ALLOW_PRIVATE_HOSTS`, `VOYAGE_EMBEDDING_MODEL`, `LOCAL_EMBEDDING_MODEL`, `EMBEDDING_API_KEY` (local), `EMBEDDING_DIMENSIONS` (must match `chunks.embedding` / reindex if changed), `LOG_FORMAT` (`json` default in the image), `RAILS_LOG_LEVEL`, `RATE_LIMIT_*`, chunk/top-k settings from `.env.example`.

## Docker image

```bash
docker build -t rag-service .
docker run --rm -p 80:80 \
  -e RAILS_MASTER_KEY=... \
  -e DB_HOST=... \
  -e RAG_SERVICE_DATABASE_PASSWORD=... \
  -e OPERATOR_API_KEY=... \
  -e EMBEDDING_PROVIDER=openai \
  -e OPENAI_API_KEY=... \
  -e ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=... \
  -e ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=... \
  rag-service
```

Health: `GET /up` is liveness (process is running). `GET /health` is readiness (returns `503` when the database is unreachable).

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
export OPENAI_API_KEY=...                # or VOYAGE_API_KEY / EMBEDDING_API_KEY, to match EMBEDDING_PROVIDER
# From `bin/rails db:encryption:init` (store these somewhere safe):
export ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=...
export ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=...
```

5. Ensure `config/master.key` exists locally (for `RAILS_MASTER_KEY` in `.kamal/secrets`).
6. Boot accessories + app:

```bash
bin/kamal setup    # first time (registry login, accessory, deploy)
bin/kamal deploy   # later releases
bin/kamal logs -f
```

Ingest jobs run in a separate `job` container (`bin/jobs`), so a heavy PDF does not compete with live queries. On a very small server you can remove the `job` role and set `SOLID_QUEUE_IN_PUMA: true` to run jobs inside the web process instead.

### Upgrading an existing deployment

1. Add the two `ACTIVE_RECORD_ENCRYPTION_*` secrets before deploying.
2. Deploy. Migrations add the vector index (built without locking writes), embedding model tracking, and API key revocation columns.
3. Run `bin/kamal app exec "bin/rails rag:encrypt_webhook_secrets"` once to encrypt webhook secrets saved before this release. Until then they stay readable as plain text.

### Switching embedding models

Each chunk records the model that embedded it, and search only compares chunks from the configured model, so a switch never mixes vectors. After changing `EMBEDDING_PROVIDER` or the model name:

```bash
bin/kamal deploy
bin/kamal app exec "bin/rails rag:reindex_stale_embeddings"
```

Documents are missing from search results until their re-ingest finishes. Changing dimensions also requires a migration.

### Backups (not set up by this repo)

Postgres data and uploaded files both live on the server's disk (`data` directory of the `db` accessory and the `rag_service_storage` volume). Nothing here copies them elsewhere. Before relying on this in production, schedule `pg_dump` of `rag_service_production` to off-server storage, back up the storage volume (or move Active Storage to S3-compatible storage in `config/storage.yml`), and test a restore.

### Error tracking

Errors are written to the log as single JSON lines with `"event":"error_reported"`. To send them to an error tracker, subscribe its reporter in `config/initializers/error_reporting.rb`.

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
4. Add a **Background Worker** with start command `bin/jobs` (or set `SOLID_QUEUE_IN_PUMA=true` on the web service to run jobs in-process).
5. Point health checks at `/up`.

## After deploy

```bash
# Mint a tenant key (operator)
curl -s -X POST https://YOUR_HOST/api_keys \
  -H "Authorization: Bearer $OPERATOR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"api_key":{"name":"prod","tenant_name":"Acme"}}'

# List a tenant's keys, then revoke one
curl -s "https://YOUR_HOST/api_keys?tenant_id=1" -H "Authorization: Bearer $OPERATOR_API_KEY"
curl -s -X DELETE https://YOUR_HOST/api_keys/1 -H "Authorization: Bearer $OPERATOR_API_KEY"
```

See `examples/` for retrieve → own LLM client samples.
