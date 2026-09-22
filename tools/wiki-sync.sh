#!/usr/bin/env bash
#
# wiki-sync.sh — publish the generated wiki to GitHub.
#
# THE WIKI USED TO BE A MIRROR OF docs/ AND IS NOT ANY MORE. Thirty-eight design documents, sixteen
# thousand lines arguing about why the game is shaped the way it is, published verbatim to a public
# page nobody could find an item on. Those arguments are for whoever is CHANGING the game and they
# belong beside the code, where a change and the reason for it land in one commit. A wiki is read by
# somebody who wants to know what a thing DOES.
#
# So the wiki mirrors the DATA now: tools/wiki_gen.lua renders every item out of the blueprints -- by
# class, then by type -- with every number read the way the game reads it. docs/ is untouched and is
# still the design source; it is simply no longer published. This script builds those pages and pushes
# them, and its prune step is what actually retires the old doc pages (see below).
#
# Usage:
#   tools/wiki-sync.sh [WIKI_DIR] [--push] [--no-build]
#   tools/wiki-sync.sh --build-only
#   tools/wiki-sync.sh --install-hook
#
#   WIKI_DIR        path to the cloned wiki repo (default: ../LoveTactics.wiki)
#   --push          git add/commit/push the wiki after syncing (otherwise leaves it dirty for you to
#                   review and commit yourself)
#   --no-build      publish whatever is already in wiki/ instead of regenerating it first
#   --build-only    regenerate wiki/ and stop -- no publish, and no wiki clone needed. This is the
#                   half an editor wants while authoring: it keeps the local pages honest between
#                   commits, and it is the one call that fails loudly if a blueprint edit broke the
#                   renderer, instead of letting you find out at commit time.
#   --install-hook  (re)install the post-commit hook that auto-syncs when the game's data changes
#
# FRESH CLONE? Two one-time steps — .git/hooks is not tracked, so the hook does not come with the repo:
#   git clone https://github.com/xenonsin/LoveTactics.wiki.git ../LoveTactics.wiki
#   tools/wiki-sync.sh --install-hook
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/wiki"

WIKI_DIR=""
DO_PUSH=0
DO_BUILD=1
INSTALL_HOOK=0
BUILD_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --push) DO_PUSH=1 ;;
    --no-build) DO_BUILD=0 ;;
    --build-only) BUILD_ONLY=1 ;;
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
# post-commit: when a commit changes what the wiki is a picture OF, regenerate and push it.
#
# That used to be docs/*.md and is now the data layer -- the blueprints the pages are rendered from,
# plus the renderer itself. Thin wrapper: all logic lives in the versioned tools/wiki-sync.sh. This
# hook is local to your clone (.git/hooks is not tracked); reinstall after a fresh clone with:
# tools/wiki-sync.sh --install-hook
# Runs after the commit is finalized, so any failure here only warns and never rolls back your commit.
# Set LOVETACTICS_WIKI_NOSYNC=1 to skip.
#
[ -n "$LOVETACTICS_WIKI_NOSYNC" ] && exit 0

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0

# WHAT COUNTS AS A CHANGE TO THE WIKI IS WIDER THAN data/, and the narrow version of this test was a
# stale public page waiting to happen. The pages are not a copy of the blueprints: every number on
# them is COMPUTED, through Item.growth, Item.instantiate, Spoils.depthOf, Class and Trait. So a
# commit touching only models/ can move every rank and every stat on all 46 class pages while this
# hook, matching '^data/', sits it out -- and nothing downstream would ever notice, because the next
# data commit republishes the corrected numbers under an unrelated message.
#
# The fix is NOT a list of the modules wiki_gen requires. Resolved transitively that list is 71 files
# deep and it would be a hand-copy that goes stale the first time the renderer grows a require --
# exactly the failure it is meant to prevent. So the trigger is any Lua at all, and THE GENERATED
# DIFF IS THE REAL GATE: the errors are asymmetric, a false positive costs four seconds and publishes
# nothing (wiki-sync finds no changes to commit), a false negative costs a wrong page on the internet.
if ! git diff-tree --no-commit-id --name-only -r HEAD | grep -qE '\.lua$'; then
  exit 0
fi

# Quiet unless the wiki actually moved -- most commits touch Lua that no page is rendered from, and a
# hook that announces itself on every one of those teaches you to stop reading it.
if out="$(bash "$REPO_ROOT/tools/wiki-sync.sh" --push 2>&1)"; then
  case "$out" in
    *"No changes to commit."*) : ;;
    *) echo "[wiki] pages changed - regenerated and pushed." ;;
  esac
else
  echo "[wiki] sync/push failed (commit is unaffected). Run 'bash tools/wiki-sync.sh --push' manually." >&2
  echo "$out" >&2
fi
exit 0
HOOK
  chmod +x "$HOOK_PATH"
  echo "Installed post-commit hook: $HOOK_PATH"
  echo "Commits touching any .lua will now rebuild the wiki, and push it if the pages changed."
  exit 0
fi

if [ "$BUILD_ONLY" -eq 0 ] && [ ! -d "$WIKI_DIR/.git" ]; then
  echo "error: '$WIKI_DIR' is not a git repo." >&2
  echo "clone it first:  git clone https://github.com/xenonsin/LoveTactics.wiki.git \"$WIKI_DIR\"" >&2
  exit 1
fi

# --- build -------------------------------------------------------------------
# The pages come out of the game's own model layer, so building them means running LÖVE. Looked up
# rather than hardcoded -- $LOVE_BIN wins, then whatever is on PATH, then the path this project's
# docs use. The console build (lovec) is preferred so `. wiki-gen`'s report is visible.
find_love() {
  if [ -n "${LOVE_BIN:-}" ]; then printf '%s' "$LOVE_BIN"; return 0; fi
  for candidate in lovec love /e/LOVE/lovec.exe /c/Program\ Files/LOVE/lovec.exe; do
    if command -v "$candidate" >/dev/null 2>&1; then printf '%s' "$candidate"; return 0; fi
    if [ -x "$candidate" ]; then printf '%s' "$candidate"; return 0; fi
  done
  return 1
}

if [ "$BUILD_ONLY" -eq 1 ]; then
  if LOVE="$(find_love)"; then
    (cd "$REPO_ROOT" && "$LOVE" . wiki-gen)
    exit $?
  fi
  echo "error: LÖVE not found. Set LOVE_BIN or put love/lovec on PATH." >&2
  exit 1
fi

if [ "$DO_BUILD" -eq 1 ]; then
  if LOVE="$(find_love)"; then
    echo "Building pages with '$LOVE . wiki-gen'..."
    (cd "$REPO_ROOT" && "$LOVE" . wiki-gen)
  else
    echo "error: LÖVE not found. Set LOVE_BIN, put love/lovec on PATH, or pass --no-build" >&2
    echo "       after running:  & \"E:\\LOVE\\lovec.exe\" . wiki-gen" >&2
    exit 1
  fi
fi

shopt -s nullglob
PAGES=("$BUILD_DIR"/*.md)
shopt -u nullglob
if [ "${#PAGES[@]}" -eq 0 ]; then
  echo "error: no pages in '$BUILD_DIR'. Run:  & \"E:\\LOVE\\lovec.exe\" . wiki-gen" >&2
  exit 1
fi

# --- publish ------------------------------------------------------------------
echo "Syncing ${#PAGES[@]} pages -> $WIKI_DIR"
declare -A KEEP=()
for page in "${PAGES[@]}"; do
  pb="$(basename "$page")"
  cp "$page" "$WIKI_DIR/$pb"
  KEEP["$pb"]=1
done

# --- prune ------------------------------------------------------------------
# A page this pipeline no longer writes. It is what retires the thirty-eight doc pages in one pass --
# they are not deleted by name, they simply stop being generated, and anything generated that is no
# longer generated goes.
#
# Only GENERATED pages are eligible, and the banner is the proof of ownership: a page one of our tools
# wrote says so on its first line, so a hand-made wiki page is left alone no matter what we publish.
# BOTH banners count -- the old "GENERATED from docs/ ... by tools/wiki-sync.sh" and the new
# "GENERATED from data/ ... by `. wiki-gen`" -- because the whole point of this run is that the first
# kind is now stale. (The honest way this was learned the first time: docs/temptation.md was deleted
# and Temptation.md stayed up, unlinked from anything and still the top Google hit for a mechanic that
# no longer existed.)
shopt -s nullglob
for page in "$WIKI_DIR"/*.md; do
  pb="$(basename "$page")"
  [ -n "${KEEP[$pb]:-}" ] && continue
  head -n1 "$page" | grep -qE 'GENERATED from (docs/|data/)' || continue
  rm -f "$page"
  echo "  pruned $pb (no longer generated)"
done
shopt -u nullglob

if [ "$DO_PUSH" -eq 1 ]; then
  cd "$WIKI_DIR"
  git add -A
  if git diff --cached --quiet; then
    echo "No changes to commit."
  else
    git commit -m "Sync wiki from data/ ($(date +%Y-%m-%d))"
    git push
    echo "Pushed."
  fi
else
  echo
  echo "Done (not committed). Review, then:"
  echo "  cd \"$WIKI_DIR\" && git add -A && git commit -m 'Sync wiki from data/' && git push"
fi
