# Cloudflare Worker

This folder contains the free deployment backend for the project:

- `Cloudflare Pages` serves the Flutter web build
- `Workers` exposes the API
- `D1` stores normalized batch/card/activity data
- `KV` caches recent pick targets and settlement summaries

## Setup

1. Create a D1 database and KV namespace.
2. Replace the placeholders in [wrangler.toml](/Users/yitianwu/Documents/card-bookkeeping/cloudflare/wrangler.toml).
3. Install dependencies:

```bash
cd cloudflare
pnpm install
```

4. Apply the schema:

```bash
pnpm wrangler d1 migrations apply card-bookkeeping-db
```

5. Deploy the API:

```bash
pnpm deploy
```

## Legacy migration

You can import the previous GitHub `data.json` snapshot directly into the new worker:

```bash
node scripts/migrate-legacy.mjs \
  --source ./legacy-data.json \
  --api-base https://card-bookkeeping-api.example.workers.dev \
  --workspace-pin YOUR_PIN
```
