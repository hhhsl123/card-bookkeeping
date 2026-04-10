#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
API_URL="https://card-bookkeeping-api.ywu1286.workers.dev"
APK_DIR="$REPO_ROOT/flutter_app/build/app/outputs/flutter-apk"

echo "=== 更新部署 ==="

# Backend
echo "🚀 部署后端..."
cd "$REPO_ROOT/cloudflare"
npx wrangler deploy 2>&1 | grep -E 'Uploaded|Deployed|https://'

# Frontend
cd "$REPO_ROOT/flutter_app"
export PATH="$HOME/.pub-cache/bin:$PATH"

echo "🔨 构建 Web..."
fvm flutter build web --release --dart-define="API_BASE_URL=$API_URL" > /dev/null 2>&1

echo "🔨 构建 APK..."
fvm flutter build apk --release --dart-define="API_BASE_URL=$API_URL" > /dev/null 2>&1

echo "🌐 部署 Pages..."
cp web/_redirects build/web/_redirects
npx wrangler pages deploy build/web --project-name card-bookkeeping --commit-dirty=true 2>&1 | grep -E 'Success|Deploying|complete'

echo ""
echo "✅ 全部更新完成"
echo "APK: $APK_DIR/app-release.apk"

# Open APK directory
open "$APK_DIR"
