#!/usr/bin/env bash
set -euo pipefail

echo "=== Card Bookkeeping 一键部署 ==="
echo ""

# Check prerequisites
for cmd in wrangler npm flutter; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "❌ 需要先安装 $cmd"
    [ "$cmd" = "wrangler" ] && echo "   运行: npm install -g wrangler"
    [ "$cmd" = "flutter" ] && echo "   参考: https://docs.flutter.dev/get-started/install"
    exit 1
  fi
done

# Check Cloudflare login
if ! wrangler whoami &> /dev/null; then
  echo "🔑 请先登录 Cloudflare..."
  wrangler login
fi

echo "✅ Cloudflare 已登录"
echo ""

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT/cloudflare"

# Step 1: Create D1 database
echo "📦 创建 D1 数据库..."
D1_OUTPUT=$(npx wrangler d1 create card-bookkeeping-db 2>&1 || true)

if echo "$D1_OUTPUT" | grep -q "already exists"; then
  echo "   数据库已存在，跳过创建"
  D1_ID=$(grep 'database_id' wrangler.toml | head -1 | sed 's/.*= *"\(.*\)"/\1/')
else
  D1_ID=$(echo "$D1_OUTPUT" | grep 'database_id' | sed 's/.*= *"\(.*\)"/\1/')
  echo "   ✅ D1 数据库已创建: $D1_ID"
fi

if [ -z "$D1_ID" ]; then
  echo "❌ 无法获取 D1 数据库 ID，请检查输出："
  echo "$D1_OUTPUT"
  exit 1
fi

# Step 2: Create KV namespace
echo "📦 创建 KV 命名空间..."
KV_OUTPUT=$(npx wrangler kv namespace create APP_CACHE 2>&1 || true)

if echo "$KV_OUTPUT" | grep -q "already exists"; then
  echo "   KV 命名空间已存在，跳过创建"
  KV_ID=$(grep 'id = ' wrangler.toml | tail -1 | sed 's/.*= *"\(.*\)"/\1/')
else
  KV_ID=$(echo "$KV_OUTPUT" | grep '"' | grep -oE '[a-f0-9]{32}')
  echo "   ✅ KV 命名空间已创建: $KV_ID"
fi

if [ -z "$KV_ID" ]; then
  echo "❌ 无法获取 KV 命名空间 ID，请检查输出："
  echo "$KV_OUTPUT"
  exit 1
fi

# Step 3: Update wrangler.toml
echo "📝 更新 wrangler.toml..."
sed -i.bak "s/database_id = \".*\"/database_id = \"$D1_ID\"/" wrangler.toml
sed -i.bak "s/^id = \".*\"/id = \"$KV_ID\"/" wrangler.toml
rm -f wrangler.toml.bak
echo "   ✅ 配置已更新"

# Step 4: Install dependencies & deploy backend
echo "📦 安装后端依赖..."
npm install --silent

echo "🗄️  执行数据库迁移..."
npx wrangler d1 migrations apply card-bookkeeping-db --remote 2>&1 | tail -5

echo "🚀 部署后端..."
DEPLOY_OUTPUT=$(npx wrangler deploy 2>&1)
WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep 'https://' | grep 'workers.dev' | sed 's/.*\(https:\/\/[^ ]*\).*/\1/' | head -1)
echo "   ✅ Worker 已部署: $WORKER_URL"

# Step 5: Build & deploy frontend
cd "$REPO_ROOT/flutter_app"

echo "📦 安装前端依赖..."
if ! flutter pub get > /dev/null 2>&1; then
  echo "   ❌ flutter pub get 失败"
  flutter pub get
  exit 1
fi

echo "🔨 构建 Web..."
if ! flutter build web --release > /dev/null 2>&1; then
  echo "   ❌ Web 构建失败"
  flutter build web --release
  exit 1
fi
cp web/_redirects build/web/_redirects 2>/dev/null || true
echo "   ✅ Web 构建完成"

echo "🌐 部署到 Cloudflare Pages..."
if ! wrangler pages deploy build/web --project-name card-bookkeeping --commit-dirty=true 2>&1 | tail -3; then
  echo "   ❌ Pages 部署失败"
  exit 1
fi
echo "   ✅ Pages 已部署"

echo ""
echo "🔨 构建 Android APK..."
if ! flutter build apk --release > /dev/null 2>&1; then
  echo "   ⚠️ APK 构建失败（可选，继续）"
  APK_PATH="(构建失败)"
else
  APK_PATH="$REPO_ROOT/flutter_app/build/app/outputs/flutter-apk/app-release.apk"
  echo "   ✅ APK: $APK_PATH"
fi

echo ""
echo "==================================="
echo "🎉 部署完成！"
echo ""
echo "后端 API:  $WORKER_URL"
echo "前端网页:  https://card-bookkeeping.pages.dev"
echo "安卓 APK:  $APK_PATH"
echo ""
echo "注意：当前数据同步通过 GitHub，不依赖后端 API"
echo "==================================="
