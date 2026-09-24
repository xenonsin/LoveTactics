#!/usr/bin/env bash
#
# wiki-watch.sh -- rebuild the wiki the moment a blueprint it renders is edited, not at commit time.
#
# The post-commit hook (tools/wiki-sync.sh --install-hook) is what PUBLISHES the wiki, and it is
# still the only thing that pushes. This is the other half: a Claude Code PostToolUse hook, so the
# generated pages in wiki/ track the blueprints while you are authoring, and -- the part that earns
# its four seconds -- a blueprint edit that BREAKS the renderer is reported against the edit that
# broke it, instead of surfacing at commit time behind whatever you did next.
#
# Wire it up in .claude/settings.json:
#   "PostToolUse": [{ "matcher": "Write|Edit",
#                     "hooks": [{ "type": "command", "command": "bash tools/wiki-watch.sh" }] }]
#
# WHY THIS READS THE PAYLOAD WITH A SUBSTRING TEST AND NOT A JSON PARSE: there is no jq on the
# machines this repo is developed on, and the question being asked is cheap -- does this tool call
# concern a blueprint the wiki renders at all? The errors are asymmetric in the same direction they
# are in the
# commit hook: a false positive costs one four-second rebuild of a gitignored folder, a false
# negative costs a wiki/ that silently disagrees with data/.
#
# FOUR FOLDERS, NOT ONE, because the wiki is not only the shelves any more. data/characters/ is the
# bestiary, data/races/ decides which page a body lands on, and data/encounters/ is what the rift's
# floors and the whole placement measurement are read out of -- an edit to any of them moves pages.
#
# AND SIX MORE FOR THE STATUS PAGE. data/status/ is the page itself; the other five are read by source
# scan for who applies, ends or wards a status (traits fold into the items that carry them, and a
# ground, a trap, a curse or an injury is named on the entry it lands).
# The list is deliberately short of the transitive truth (the renderer reads seventy-odd files through
# the models); the post-commit hook is the backstop for everything else, because it fires on any .lua
# at all and its generated diff is the gate.
#
# THE PATH IS NORMALISED BEFORE IT IS MATCHED, and the first cut of this file got that wrong in the
# way that leaves no trace: on Windows the payload spells the path E:\Projects\...\data\items\..,
# and JSON escapes every one of those backslashes again, so what actually arrives is `data\\items`.
# Matching the spellings one by one looked right and silently matched nothing -- the hook exited 0,
# rebuilt nothing, and a timing check was the only thing that showed it. So: fold backslashes to
# slashes and squeeze the runs, then there is ONE spelling to match.
#
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

payload="$(cat 2>/dev/null || true)"
payload="$(printf '%s' "$payload" | tr '\\' '/' | tr -s '/')"

case "$payload" in
    *data/items/*|*data/characters/*|*data/races/*|*data/encounters/*|*wiki_gen.lua*) ;;
    *data/status/*|*data/traits/*|*data/hazards/*|*data/traps/*|*data/curses/*|*data/injuries/*) ;;
    *) exit 0 ;;
esac

if ! out="$(bash "$REPO_ROOT/tools/wiki-sync.sh" --build-only 2>&1)"; then
    # The blueprint just edited does not survive the renderer -- which means it does not survive the
    # game's own model layer either, since that is what wiki_gen reads it through. Exit 2 so the
    # message goes back to Claude rather than scrolling past as ignored stdout.
    echo "[wiki] regeneration FAILED after this edit -- the blueprint does not load:" >&2
    echo "$out" >&2
    exit 2
fi

exit 0
