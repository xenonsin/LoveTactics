# Roadmap — what is left before this is a finished game

This is the working backlog, ordered. It exists because the gap between "the engine is done" and
"the game is done" is almost entirely **content and presentation**, and that gap is invisible from
inside the code: `models/sprite.lua` resolves a missing image to its own path string rather than
crashing, quests with no authored scene still run, and a game with no audio still boots. Nothing
goes red. So the debt has to be counted deliberately, and this is where the count lives.

Two rules for maintaining this file:

- **Every number here is reproducible.** Each section says the command or query that regenerates it.
  Do not hand-edit a count; re-run the check and paste what it says.
- **Items only leave by being done.** Like `tests/support/untested_items.lua`, this ratchets down.
  If something is cut rather than built, say so in the item and leave the line.

Note that `docs/*.md` is mirrored to the GitHub wiki by `tools/wiki-sync.sh` on commit, so this page
is public the moment it is committed alongside any other doc change.

## Snapshot

Regenerate with `& "E:\LOVE\lovec.exe" . test`, `. art-report` and `. audio-report`.

| | state |
|---|---|
| Test suite | 1326 passing, 0 failing |
| Items | 558, all under the universal contract; 248 with a bespoke case |
| Quests | 94 blueprints — **71 with no authored scene** |
| Conversations | 73 — 20 of them the Bastion alone |
| Characters | 64 blueprints |
| Art | 131 of 644 referenced assets missing — **every portrait, character and vendor** |
| Audio | system built and wired; **0 of 23 cues have a file** (`. audio-report`) |
| Localization | 510 of 523 strings untranslated (`ja = ""`) |
| Two-phase general fights | 0 of 7 built |

## Phase 1 — close the spine

**Phase 1 is complete.** All three items are in *Already closed* below. The critical path now runs from
the prologue to an ending, every companion has a join scene, and all seven generals speak.

1. ~~**The finale has no dialogue and no ending.**~~ **Done.**
2. ~~**Amana joins silently.**~~ **Done.**
3. ~~**Ira has no confront scene.**~~ **Done.**

## Phase 2 — audio, as a system before it is content

**The system is built AND fully wired (items 4–7); only the content is left.** The game is still silent,
but it is now silent the way it was once artless: every one of the 23 cues is declared, counted, and
called from gameplay, so a file dropped at the path its cue names starts playing with no code change.
`tests/audio_wiring_spec.lua` pins the signals so no cue can go silent at its source unnoticed.

4. ~~**`models/sound.lua`**~~ **Done.**
5. ~~**Volume settings**~~ **Done.**
6. ~~**Cue points declared in data**~~ **Done.**
7. ~~**An `. audio-report` entry point**~~ **Done.**
8. **The audio content.** 23 cues, 0 recorded: 6 music beds, 4 UI, 10 battle, 3 progress stings. Run
   `. audio-report missing` for the exact paths. The brief is written — [docs/audio-assets.md](audio-assets.md),
   beside the art brief — and **every cue is now wired**, so this is purely a sourcing job: record or
   source the 23 files (CC0 preferred; no AI) and drop each at its path. Priority order in the brief.
   **This is the only part of Phase 2 left.**

## Phase 3 — the silent quests

The bulk of the remaining authoring. 72 of 94 quests have no `intro`, `outro`, or `opening`. The
37-quest pass that filled the six lines' empty slots deliberately shipped them bare, because
`Conversation.play` asserts on an unknown id and a dead reference is worse than none.

9. **Scenes for the 72.** The Bastion is the worked example — 20 conversations, intro and outro on
   every slot. Copy its shape per line. Companions get `when = { has = ... }` blocks so every scene
   is authored for the full roster.
10. **Slot 5 unbuyables.** Each line's slot 5 owes a register-style reward item; none are written,
    which is why those quests set no `rewardItems`.
11. **Slot 8 second relics** for Saber, Kaya, Ren, Gyeom and Clem. Rowan's and Amana's exist.
12. **Stand-in enemy blueprints.** Where a slot wanted a body that does not exist — the Perennial's
    fighters, the anointed, the turning wardens, the Bank's chartered security — the quest stands in
    with a shipped blueprint and says so in its header. Each is a named, findable debt.
13. **The slot-7 no-fight seam.** Every line's slot 7 was designed as a scene without a battle; the
    engine has no such thing, so all six ship as fights. Either build the seam or ratify the fights.

## Phase 4 — the seven finales

14. **Two-phase general transforms — 0 of 7.** `models/transform.lua` ships and no general consumes
    it; the health-threshold precedent is `trait_hollow_crown`. Every general is currently a
    single-phase fight, which is not what any of them are designed as.
15. **Aurea's gold subsystem** — the one genuinely large piece: a gold pool that wards her (blows
    subtract from gold, not HP), gates her every action, refills on the Golden Touch, drops as
    board pickups, and triggers the bankruptcy two-phase. New engine on the order of
    `trait_hollow_crown`. She currently ships as an ordinary HP-pool general.
16. **Per-general phase-two kits** — Livia's Envious Pall / Covet / Grudge, Sublimitas's full
    learn-and-recast mirror over the shipped counter-magic reflex, Luxuria's drain-and-turn,
    Aurea's hired-blade gold-cost summons.

## Phase 5 — art

17. **131 assets outstanding**, but the distribution is the story: items are 502/544, and *every
    human being in the game is 0%* — 19 portraits, 56 character sprites, 8 vendors, the hub
    background, 4 overworld, 1 font. The game renders nobody. This is an artist's job, not a
    coding one; the deliverable here is the brief and the priority order in
    [docs/art-assets.md](art-assets.md), and the report already counts the rest.

## Phase 6 — polish and open decisions

18. **Localization** — 510 of 523 strings are `ja = ""`. The system works; the translation has not
    happened. Mechanical, and safely last.
19. **Reputation ladder shape** — rank 4 now lands a slot or two early after the grind removal; only
    count-based standing (`ranks = { 0, 3, 6, 9 }`) puts it back on the ninth. Engine work in
    `Player.addReputation` / `Vendor.rankFor`. No quest has to move when it happens.
20. **Unresolved character TODOs** carried in the blueprints — Clem's flaw (forgives every debt but
    her own), Ren's flaw (the giver who never receives), Kaya's temperance-immunity fold-in.
21. **The Ira contradiction — a decision, not a task.** Every general is meant to be a human who
    pacted with the Demon Lord; Ira is written as a *manufactured* woman who never chose, and
    `docs/story.md` says explicitly to leave the contradiction standing until it is resolved on
    purpose, and not to quietly rewrite her. Either she is the one general the rule spares, or the
    pact was the Perennial's, struck on her behalf. **Owed: a call.**

## Done

- **The campaign has an ending (item 1).** The finale now plays `gate_below_confront` over the boss
  fight — the Crown has nothing of its own to say, so it quotes the dead generals back at whichever
  companions are present — and `gate_below_ending` over the frozen final frame. Completion routes to
  a new `states/credits.lua` instead of the hub, driven by an `endsCampaign` flag on the quest rather
  than a quest id the engine knows, so a second ending is a data edit. The roll carries the
  game-icons.net attribution required by CC BY 3.0, read from a generated `data/credits_icons.lua`
  so it cannot drift out of licence. `Player.newGamePlus` then carries the company, its gear and its
  prestige forward while clearing completed quests and vendor reputation, which puts all seventy line
  slots back on the board and re-locks the Gate. Covered by `tests/ending_spec.lua`.
- **Amana's plea (item 2).** `amana_joins` is the `outro` of her recruit quest — the scene the
  Cathedral's ten-slot table specifies as *"bested, Amana stays your hand and her plea reveals the
  truth; she joins."* It delivers the blooding: demon's blood in the rite, the failures hunted as
  "demons from the wild" (the work the player is being paid for), the dead written into the register
  as *ascended to the Light*. The constraint that shapes every line is what she **cannot** say — she
  does not yet know the Saint is the demon, which is slot 7's to break, so she reaches for the Saint
  as the authority who would stop this if only she knew. Everything she says about the altar is
  sincere and wrong. Rowan and Saber answer hardest: one's order writes its dead into a roll of
  martyrs by the same trick, the other came out of an intake that also took children.
- **Ira's confront (item 3).** `colosseum_general_wrath_confront` — the last general to get a voice.
  Written against the doc's hard rules: she never asks to die (that would let Saber off), the horror
  stays bureaucratic (a handler *reassigned*, a form, not a murder), there is no one to be paid by,
  and she reads the room by sound because she is blind from birth. It deliberately does **not** settle
  whether she is the general the pact rule spares — no line claims she agreed to anything, per the
  standing instruction not to quietly rewrite her.
- **The audio system (items 4–7).** `models/sound.lua` is the audio twin of `models/sprite.lua` and
  built to the same tolerance rule — a missing file is silence, never an error — which is the property
  that let 502 item icons land one at a time and is the only reason audio can arrive the same way.
  `data/sounds.lua` declares all 23 cues as data; `. audio-report` counts them against disk the way
  `. art-report` does for images. Master/music/effects volumes are persisted preferences using a new
  `range` option kind, and the settings screen steps them through the menu widget's existing
  `adjust` hook — no widget changes needed. Cues are wired at the shared seams: the menu widget
  (covering every menu at once), battle start with a boss/ordinary music split, the beds for menu,
  hub, overworld and credits, and the quest-complete sting. Covered by `tests/sound_spec.lua`.
- **A third bug, this one user-visible: the Settings screen could not be left.** Same root cause as the
  credits one — `State.switch` passes a state its own table first, and `settings.enter(previous)` bound
  `previous` to the settings table, so Back and Esc both switched to settings again. Fixed, and every
  other state's `enter` audited (all of them already led with `self` or `_`).
- **A layout regression I caused and the screenshot caught.** Adding three volume rows pushed the
  option description into the input hint at the bottom of the settings screen. Both are now anchored to
  the bottom rather than trailing the list, so adding options eats slack instead of overprinting text.
- **Two bugs found while building the ending, both fixed:**
  - `tools/extract_strings.lua` regenerated each conversation file from the parsed def, silently
    **destroying every hand-written header comment** the moment that conversation gained a line
    needing a tag. Several shipped scenes were one re-stamp away from losing their only design notes.
    Headers are now read back off disk and re-emitted; `tests/extract_strings_spec.lua` pins it.
  - `states/init.lua` calls `state.enter(state, ...)`, so a state's own table always arrives as the
    first argument. The credits screen was written `enter(opts)` and consequently offered no New
    Game+ at all — caught by looking at the rendered screen, not by any test.

- **Item test coverage ratchet is green.** `tests/discipline_wave2d_spec.lua` closed the last three
  uncovered items (`ability_lay_on_hands`, `ability_oathkeepers_litany`, `armor_vow_marked_plate`),
  taking the suite to 1259 passing, 0 failing.
- **All sixty line slots exist on disk.** The 37-quest pass filled every empty slot across the six
  lines. They are bare (see Phase 3), but no slot is missing.
- **The grind is gone.** Every `repeatable` quest was removed and reputation retuned; each line
  clears its own ladder without replaying anything.
