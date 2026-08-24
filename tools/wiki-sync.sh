#!/usr/bin/env bash
#
# wiki-sync.sh — mirror docs/*.md into the GitHub wiki working copy.
#
# docs/ is the single source of truth. This script copies each doc into the wiki
# repo under a Title-Cased-Hyphenated page name, rewrites intra-doc markdown links
# to wiki page links, and (re)generates Home.md and _Sidebar.md. Every synced page
# gets a "generated — edit the source doc" banner so nobody hand-edits the mirror.
#
# Usage:
#   tools/wiki-sync.sh [WIKI_DIR] [--push]
#   tools/wiki-sync.sh --install-hook
#
#   WIKI_DIR        path to the cloned wiki repo (default: ../LoveTactics.wiki)
#   --push          git add/commit/push the wiki after syncing (otherwise leaves it
#                   dirty for you to review and commit yourself)
#   --install-hook  (re)install the post-commit hook that auto-syncs on doc changes
#
# FRESH CLONE? Two one-time steps — .git/hooks is not tracked, so the hook does not
# come with the repo:
#   git clone https://github.com/xenonsin/LoveTactics.wiki.git ../LoveTactics.wiki
#   tools/wiki-sync.sh --install-hook
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"

WIKI_DIR=""
DO_PUSH=0
INSTALL_HOOK=0
for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=1 ;;
    --install-hook) INSTALL_HOOK=1 ;;
    *) WIKI_DIR="$arg" ;;
  esac
done
[ -n "$WIKI_DIR" ] || WIKI_DIR="$(cd "$REPO_ROOT/.." && pwd)/LoveTactics.wiki"

# --- --install-hook: write .git/hooks/post-commit and exit ---------------------
if [ "$INSTALL_HOOK" -eq 1 ]; then
  HOOK_PATH="$(git -C "$REPO_ROOT" rev-parse --git-path hooks/post-commit)"
  [ -e "$HOOK_PATH" ] && echo "note: overwriting existing $HOOK_PATH"
  cat > "$HOOK_PATH" <<'HOOK'
#!/usr/bin/env bash
#
# post-commit: when a commit touches docs/*.md, regenerate and push the GitHub wiki.
#
# Thin wrapper — all logic lives in the versioned tools/wiki-sync.sh. This hook is
# local to your clone (.git/hooks is not tracked); reinstall after a fresh clone
# with: tools/wiki-sync.sh --install-hook
# Runs after the commit is finalized, so any failure here only warns and never
# rolls back your commit. Set LOVETACTICS_WIKI_NOSYNC=1 to skip.
#
[ -n "$LOVETACTICS_WIKI_NOSYNC" ] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# Did this commit change any doc? If not, nothing to sync.
if ! git diff-tree --no-commit-id --name-only -r HEAD | grep -qE '^docs/.+\.md$'; then
  exit 0
fi

echo "[wiki] docs/ changed - syncing wiki..."
if bash "$REPO_ROOT/tools/wiki-sync.sh" --push; then
  echo "[wiki] done."
else
  echo "[wiki] sync/push failed (commit is unaffected). Run 'bash tools/wiki-sync.sh --push' manually." >&2
fi
exit 0
HOOK
  chmod +x "$HOOK_PATH"
  echo "Installed post-commit hook: $HOOK_PATH"
  echo "Commits touching docs/*.md will now regenerate and push the wiki."
  exit 0
fi

if [ ! -d "$WIKI_DIR/.git" ]; then
  echo "error: '$WIKI_DIR' is not a git repo." >&2
  echo "clone it first:  git clone https://github.com/xenonsin/LoveTactics.wiki.git \"$WIKI_DIR\"" >&2
  exit 1
fi

# basename (no .md) -> wiki page name: split on '-', capitalize each word, rejoin.
title_of() {
  local name="$1" out="" word
  local IFS='-'
  for word in $name; do
    out="${out:+$out-}$(printf '%s' "${word:0:1}" | tr '[:lower:]' '[:upper:]')${word:1}"
  done
  printf '%s' "$out"
}

# Collect the doc list and their page titles.
declare -a BASENAMES TITLES
while IFS= read -r f; do
  b="$(basename "$f" .md)"
  BASENAMES+=("$b")
  TITLES+=("$(title_of "$b")")
done < <(find "$DOCS_DIR" -maxdepth 1 -name '*.md' | sort)

# Build a sed program that rewrites every intra-doc link:
#   ](docs/NAME.md#frag) or ](NAME.md#frag)  ->  ](Title#frag)
# The optional (docs/) prefix and optional (#fragment) are both preserved. A
# non-printing delimiter (\x01) is used so the literal '#' in #fragment is safe.
D=$'\001'
SED_PROG=""
for i in "${!BASENAMES[@]}"; do
  n="${BASENAMES[$i]}"
  t="${TITLES[$i]}"
  # group 2 = optional "#fragment"
  SED_PROG+="s${D}\]\((docs/)?${n}\.md(#[^)]*)?\)${D}](${t}\\2)${D}g;"
done

banner_for() { # $1 = source basename.md
  printf '<!-- GENERATED from docs/%s by tools/wiki-sync.sh. Edit the source doc, not this page. -->\n\n' "$1"
}

echo "Syncing $((${#BASENAMES[@]})) docs -> $WIKI_DIR"
for i in "${!BASENAMES[@]}"; do
  b="${BASENAMES[$i]}"
  t="${TITLES[$i]}"
  {
    banner_for "$b.md"
    sed -E "$SED_PROG" "$DOCS_DIR/$b.md"
  } > "$WIKI_DIR/$t.md"
  echo "  $b.md -> $t.md"
done

# --- prune ------------------------------------------------------------------
# A page whose source doc is gone. The sync copied and never removed, so deleting
# docs/NAME.md left NAME's page standing on the public wiki forever -- still linked
# from nothing, still the top Google hit for a mechanic that no longer exists.
# Found the honest way: docs/temptation.md was deleted and Temptation.md stayed up.
#
# Only GENERATED pages are eligible. The banner is the proof of ownership: a page
# this script wrote says so on its first line, so a hand-made wiki page (or one from
# some future tool) is left alone no matter what docs/ holds. Home.md and _Sidebar.md
# are skipped explicitly -- they carry a banner too, and they are regenerated below
# rather than sourced from any one doc.
declare -A KEEP=()
for i in "${!TITLES[@]}"; do KEEP["${TITLES[$i]}.md"]=1; done
KEEP["Home.md"]=1
KEEP["_Sidebar.md"]=1

shopt -s nullglob
for page in "$WIKI_DIR"/*.md; do
  pb="$(basename "$page")"
  [ -n "${KEEP[$pb]:-}" ] && continue
  head -n1 "$page" | grep -q 'GENERATED from docs/.* by tools/wiki-sync.sh' || continue
  rm -f "$page"
  echo "  pruned $pb (its source doc is gone)"
done
shopt -u nullglob

# --- Home.md -----------------------------------------------------------------
{
  banner_for "(generated index)"
  cat <<'EOF'
# LoveTactics

A 2D tactics game built with [LÖVE2D](https://love2d.org/) (Lua). Seven vendors,
seven deadly sins, and a party you assemble one companion at a time.

This wiki mirrors the design docs kept in the repo's `docs/` folder. **Edit the
source docs, not these pages** — the wiki is regenerated by `tools/wiki-sync.sh`.

## Pages
EOF
  for i in "${!BASENAMES[@]}"; do
    printf -- '- [%s](%s)\n' "${TITLES[$i]}" "${TITLES[$i]}"
  done
} > "$WIKI_DIR/Home.md"

# --- _Sidebar.md -------------------------------------------------------------
{
  printf '### LoveTactics\n\n'
  printf -- '- [Home](Home)\n'
  for i in "${!BASENAMES[@]}"; do
    printf -- '- [%s](%s)\n' "${TITLES[$i]}" "${TITLES[$i]}"
  done
} > "$WIKI_DIR/_Sidebar.md"

echo "  -> Home.md, _Sidebar.md"

if [ "$DO_PUSH" -eq 1 ]; then
  cd "$WIKI_DIR"
  git add -A
  if git diff --cached --quiet; then
    echo "No changes to commit."
  else
    git commit -m "Sync wiki from docs/ ($(date +%Y-%m-%d))"
    git push
    echo "Pushed."
  fi
else
  echo
  echo "Done (not committed). Review, then:"
  echo "  cd \"$WIKI_DIR\" && git add -A && git commit -m 'Sync wiki from docs/' && git push"
fi
