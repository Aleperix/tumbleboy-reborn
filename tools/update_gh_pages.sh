#!/usr/bin/env bash
# Publica el build HTML5 (godot4/build/web) en la rama gh-pages de GitHub Pages.
#
# Uso:
#   tools/update_gh_pages.sh           # exporta web (si falta) y publica
#   tools/update_gh_pages.sh --no-export  # publica el build ya existente
#
# La web se exporta en modo single-threaded (variant/thread_support=false), así
# que NO necesita cabeceras COOP/COEP: funciona directamente en GitHub Pages.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WEB="$ROOT/godot4/build/web"
NAME="tumbleboy-reborn"
WORKTREE="${GH_PAGES_WORKTREE:-/tmp/tumbleboy-gh-pages}"
BRANCH="gh-pages"
EXPORT=1

if [ "${1:-}" = "--no-export" ]; then
	EXPORT=0
fi

if [ "$EXPORT" = "1" ] || [ ! -d "$WEB" ]; then
	echo "==> Exportando build web..."
	(cd "$ROOT/godot4" && godot --headless --path . --export-release "Web" build/web/tumbleboy-reborn.html)
fi

if [ ! -f "$WEB/$NAME.html" ]; then
	echo "error: no hay build web en $WEB" >&2
	exit 1
fi

echo "==> Preparando worktree $BRANCH en $WORKTREE"
if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
	git worktree remove --force "$WORKTREE" 2>/dev/null || true
	git worktree add --force "$WORKTREE" "$BRANCH"
else
	git worktree remove --force "$WORKTREE" 2>/dev/null || true
	git worktree add --force --detach "$WORKTREE" HEAD
	(cd "$WORKTREE" && git checkout --orphan "$BRANCH" && git rm -rf --quiet . 2>/dev/null || true)
fi

echo "==> Copiando artefactos"
git -C "$WORKTREE" rm -rf --quiet --ignore-unmatch . 2>/dev/null || true
rm -rf "$WORKTREE"/* 2>/dev/null || true
cp "$WEB/$NAME".* "$WORKTREE"/
mv "$WORKTREE/$NAME.html" "$WORKTREE/index.html"
touch "$WORKTREE/.nojekyll"
echo "TumbleBoy Reborn - version web (Godot 4)" > "$WORKTREE/README.md"

echo "==> Commit y push"
(cd "$WORKTREE" && git add -A && git commit -m "web: build HTML5 $(date -u +%Y-%m-%dT%H:%MZ)" && git push origin "$BRANCH")
echo "==> OK. GitHub Pages sirve https://<usuario>.github.io/tumbleboy-reborn/"
