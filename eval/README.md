# Retrieval eval harness

Golden Q&A set and recall@k metrics for comparing `vector` vs `hybrid` retrieval.

## Run

Uses the `fake` embedding provider by default (deterministic, no API key):

```bash
bin/rails retrieval:eval
```

Fake vectors carry no meaning, so those numbers only prove the pipeline runs end to end. To measure real search quality, run against the provider you deploy with:

```bash
EMBEDDING_PROVIDER=openai OPENAI_API_KEY=... bin/rails retrieval:eval
```

Optional custom golden file:

```bash
GOLDEN=eval/golden.json bin/rails retrieval:eval
```

## Interpreting results

For each mode (`vector`, `hybrid`) the task prints mean **recall@k** over all queries at k ∈ {1, 5, 10}.

- `recall@k` = fraction of relevant document ids that appear in the top-k retrieved document ids
- Higher is better; `1.0` means every relevant doc was retrieved within k

This rake task is intentionally **not** part of the default CI gate. A unit test covers the metric helper only.

## Golden format

See `golden.json`:

- `documents`: `{ title, content }` rows ingested into an ephemeral eval tenant
- `queries`: `{ id, query, relevant_titles }` — titles must match documents
