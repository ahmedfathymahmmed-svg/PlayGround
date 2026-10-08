#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
/usr/bin/time -p pwd
PROJECT_ROOT="$(pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
PORT="${PORT:-${APP_PORT:-3000}}"
/usr/bin/time -p mkdir -p "$DIST_DIR"
/usr/bin/time -p test -f "$DIST_DIR/index.html"
WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
export PROJECT_ROOT DIST_DIR WEB_DIR PORT
/usr/bin/time -p mkdir -p "$WEB_DIR"
/usr/bin/time -p node -e 'const fs=require("fs"); const root=process.env.PROJECT_ROOT; const dir=process.env.DIST_DIR; const web=process.env.WEB_DIR; if(!root||!dir||!web){console.error("missing env");process.exit(1)} fs.writeFileSync(web+"/deployment-output.json", JSON.stringify({project: root, directory: dir}));'
/usr/bin/time -p cat "$WEB_DIR/deployment-output.json"
if /usr/bin/time -p test -f "$PROJECT_ROOT/package.json"; then
  /usr/bin/time -p npm install --no-audit --no-fund --prefix "$PROJECT_ROOT"
  if /usr/bin/time -p bash -c 'node -e "const p=require(process.argv[1]); process.exit(p.scripts&&p.scripts.build?0:1)" "$PROJECT_ROOT/package.json"'; then
    /usr/bin/time -p npm run build --prefix "$PROJECT_ROOT"
  fi
  /usr/bin/time -p test -f "$DIST_DIR/index.html"
fi
/usr/bin/time -p python3 -m http.server "$PORT" --directory "$DIST_DIR"
