# Card Bookkeeping

Card bookkeeping for batch import, exact-value picking, settlement, and multi-device sync.

## Stack

- `flutter_app/`: Flutter Web + Android client
- `cloudflare/`: Cloudflare Worker + D1 + KV backend
- `.github/workflows/`: Flutter CI, Cloudflare deploy, Android release

## What Changed

- Replaced the old GitHub-token sync path with a Worker API scaffold
- Rebuilt the app IA to `首页 / 库存 / 提卡 / 算账 / 设置`
- Added clipboard-first import flow and exact-value picking flow
- Added Cloudflare free-tier deployment config
- Added migration tooling for legacy `data.json`
- Replaced the placeholder widget test with business-oriented tests

## Local Development

### Flutter

```bash
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=https://your-worker.workers.dev
flutter test
flutter analyze
```

### Cloudflare

```bash
cd cloudflare
pnpm install
pnpm wrangler d1 migrations apply card-bookkeeping-db
pnpm wrangler dev
```

## Deploy

- Web production: Cloudflare Pages
- API: Cloudflare Workers
- Database: Cloudflare D1
- Cache: Cloudflare KV
- Android release: GitHub Releases

Set these GitHub secrets/vars before enabling deploy workflows:

- `secrets.CLOUDFLARE_API_TOKEN`
- `secrets.CLOUDFLARE_ACCOUNT_ID`
- `vars.CLOUDFLARE_PAGES_PROJECT`
- `vars.API_BASE_URL`

## Legacy Migration

Import the previous GitHub `data.json` into the new Worker backend:

```bash
node cloudflare/scripts/migrate-legacy.mjs \
  --source ./legacy-data.json \
  --api-base https://your-worker.workers.dev \
  --workspace-pin YOUR_PIN \
  --workspace-id default
```
