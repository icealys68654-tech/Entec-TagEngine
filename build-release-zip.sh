#!/usr/bin/env bash
set -euo pipefail

WORK_DIR="entec-platform"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "1. Cloning source repositories..."
git clone --depth 1 https://github.com/icealys68654-tech/Entec.git "$TMP_DIR/Entec"
git clone --depth 1 https://github.com/icealys68654-tech/TagEngine.git "$TMP_DIR/TagEngine"

echo "2. Creating clean workspace layout..."
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR/packages/umbrella" "$WORK_DIR/packages/tagengine/src" "$WORK_DIR/packages/tagengine/public"

# Copy Entec (Umbrella + Operations Dashboard)
cp -R "$TMP_DIR/Entec/src" "$WORK_DIR/packages/umbrella/"
cp -R "$TMP_DIR/Entec/public" "$WORK_DIR/packages/umbrella/"
cp "$TMP_DIR/Entec/package.json" "$TMP_DIR/Entec/tsconfig.json" "$TMP_DIR/Entec/LICENSE" "$WORK_DIR/packages/umbrella/"

# Copy TagEngine (Server, Parser, Store, Comparator, Tests, Static Assets)
for file in server.ts cli.ts snapshot-manifest-parser.ts snapshot-store.ts sqlite-snapshot-diff-comparator.ts; do
  [ -f "$TMP_DIR/TagEngine/$file" ] && cp "$TMP_DIR/TagEngine/$file" "$WORK_DIR/packages/tagengine/src/"
done
[ -d "$TMP_DIR/TagEngine/src" ] && cp -R "$TMP_DIR/TagEngine/src/." "$WORK_DIR/packages/tagengine/src/"

for asset in index.html app.js styles.css; do
  [ -f "$TMP_DIR/TagEngine/$asset" ] && cp "$TMP_DIR/TagEngine/$asset" "$WORK_DIR/packages/tagengine/public/"
done
[ -d "$TMP_DIR/TagEngine/public" ] && cp -R "$TMP_DIR/TagEngine/public/." "$WORK_DIR/packages/tagengine/public/"

[ -d "$TMP_DIR/TagEngine/tests" ] && cp -R "$TMP_DIR/TagEngine/tests" "$WORK_DIR/packages/tagengine/"
cp "$TMP_DIR/TagEngine/package.json" "$TMP_DIR/TagEngine/LICENSE" "$WORK_DIR/packages/tagengine/"
[ -f "$TMP_DIR/TagEngine/tsconfig.json" ] && cp "$TMP_DIR/TagEngine/tsconfig.json" "$WORK_DIR/packages/tagengine/"
[ -f "$TMP_DIR/TagEngine/sample_snapshot.txt" ] && cp "$TMP_DIR/TagEngine/sample_snapshot.txt" "$WORK_DIR/packages/tagengine/"

# Ensure TagEngine tsconfig points to src/ if files were moved from root
if [ ! -f "$WORK_DIR/packages/tagengine/tsconfig.json" ]; then
  cat << 'EOF' > "$WORK_DIR/packages/tagengine/tsconfig.json"
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "rootDir": "./src",
    "outDir": "./dist",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
EOF
fi

echo "3. Writing root workspace configuration, .gitignore, and .env.example..."
cat << 'EOF' > "$WORK_DIR/.gitignore"
node_modules/
dist/
.env
.env.*
!.env.example
data/
*.sqlite
*.sqlite-wal
*.sqlite-shm
*.jsonl
.DS_Store
EOF

cat << 'EOF' > "$WORK_DIR/.env.example"
# Shared server-to-server bearer secret (generate with: openssl rand -hex 32)
ENTEC_API_TOKEN=replace-with-high-entropy-secret
TAGENGINE_API_TOKEN=replace-with-high-entropy-secret

# TagEngine service settings
NODE_ENV=production
ENTEC_SNAPSHOT_DIR=./data/snapshots

# Umbrella / Operations Dashboard settings
TAGENGINE_URL=http://127.0.0.1:3000
ENTEC_DASHBOARD_HOST=127.0.0.1
ENTEC_DASHBOARD_TOKEN=replace-with-separate-dashboard-secret
EOF

cat << 'EOF' > "$WORK_DIR/package.json"
{
  "name": "entec-platform",
  "private": true,
  "version": "1.0.0",
  "scripts": {
    "install:all": "npm --prefix packages/tagengine install && npm --prefix packages/umbrella install",
    "build:all": "npm --prefix packages/tagengine run build && npm --prefix packages/umbrella run build",
    "start:tagengine": "npm --prefix packages/tagengine start",
    "start:dashboard": "npm --prefix packages/umbrella run dashboard"
  }
}
EOF

echo "4. Installing dependencies and verifying TypeScript builds..."
(cd "$WORK_DIR/packages/tagengine" && npm install && npm run build)
(cd "$WORK_DIR/packages/umbrella" && npm install && npm run build)

echo "5. Creating GitHub-ready ZIP archive (excluding node_modules, dist, .env, data)..."
zip -r "entec-platform-github-ready.zip" "$WORK_DIR" \
  -x "*/node_modules/*" \
  -x "*/dist/*" \
  -x "*/.env" \
  -x "*/.env.*" \
  -x "*/data/*" \
  -x "*/.git/*" \
  -x "*.sqlite*"

echo "Done! Created entec-platform-github-ready.zip"
