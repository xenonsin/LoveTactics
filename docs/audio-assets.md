# Audio assets

Every sound the game can ask for, what it must be, and where it comes from. The game runs fine
without any of it — `models/sound.lua` resolves a missing file to **silence** instead of crashing,
the exact tolerance rule that let 502 item icons land one at a time — so **the audio debt is
invisible unless it is written down**. This file is where it is written down. It is the audio twin
of [art-assets.md](art-assets.md): this doc holds the decisions, and the tool holds the counts.

```powershell
& "E:\LOVE\lovec.exe" . audio-report           # summary by bucket
& "E:\LOVE\lovec.exe" . audio-report missing    # ... and the outstanding filenames
```

`tools/audio_report.lua` walks `data/sounds.lua` against disk, so the moment a file lands the count
moves on its own. Paste a fresh summary into the snapshot below when it does. Do not hand-edit a
number here — re-run the check.

## Snapshot

As of 2026-07-24 — **0 of 23 present**, 23 outstanding. Regenerate with the command above.

| bucket | have | needed | plays through |
|---|---|---|---|
| `music/` | 0 | 6 | `Sound.music(id)` — streamed, looped bed (one per place the player spends time) |
| `ui/` | 0 | 4 | `Sound.play(id)` — the shared menu widget |
| `battle/` | 0 | 10 | `Sound.play(id)` — one-shot per combat event |
| `quest/` | 0 | 3 | `Sound.play(id)` — progress stings |

The whole system (roadmap items 4–7) is built: `models/sound.lua`, `data/sounds.lua`,
`. audio-report`, and persisted master/music/effects volumes in the settings screen. **Only the
content — and the last of the wiring — is left. That is roadmap item 8.**

## Every cue is wired

All 23 cues are **called** from gameplay: dropping a file at any cue's path makes that one cue play,
with no further code change. The content is the only remainder. `tests/audio_wiring_spec.lua` pins the
signals the cues ride on, so a cue cannot go silent at its source without a test failing.

| cue | call site |
|---|---|
| `music.menu` / `.hub` / `.overworld` / `.battle` / `.boss` / `.credits` | `states/menu,hub,game,battle,credits` |
| `battle.start` | `states/battle.lua` on battle enter |
| `battle.turn` | `states/battle.lua` `beginTurn` — every turn, both sides |
| `battle.hit` / `battle.crit` | `ui/combat_fx.lua` on a damage cue (crit = a heavy blow, ≥12) |
| `battle.death` | `ui/combat_fx.lua` on a death cue |
| `battle.heal` | `ui/combat_fx.lua` on a heal cue |
| `battle.status` | `models/status.lua` raises the cue on a fresh application; played by `ui/combat_fx.lua` |
| `battle.miss` | `models/combat.lua` raises the cue on a voided blow (evade/smoke/substitute); played by `ui/combat_fx.lua` |
| `battle.win` / `battle.loss` | `states/battle.lua` `win()` / `lose()` |
| `quest.complete` | `states/game.lua` on objective clear |
| `quest.levelup` | `ui/panels/advancement.lua` when the post-quest overlay opens with level-ups |
| `quest.join` | `models/conversation.lua` `drainJoins`, as the party-join banner is folded in |
| `ui.move` / `ui.confirm` | `ui/menu.lua` (and `states/settings.lua`) |
| `ui.cancel` | `states/hub.lua` on closing a building panel or the system menu |
| `ui.denied` | `states/battle.lua` `notify` — a refused action (the wind-up readout passes `quiet`) |

Two cues are wired to the nearest real signal rather than the mechanic their name suggests, because
that mechanic does not exist in this engine:

- **`battle.crit`** — there is no critical-hit roll; the cue fires on a **heavy blow** (≥12 damage, the
  same threshold that already earns an extra screen shake). A punchier hit, not a separate RNG event.
- **`battle.miss`** — there is no accuracy roll; a blow only ever lands nothing when it is **voided**
  outright by a dodge, a smoke charge, or a substitution clone. That is what the cue marks.

## Direction

Match the art direction: **bright fantasy, not grim dark** ([art-assets.md](art-assets.md#direction)).

- **SFX are short and readable.** This is a tactics game — the player triggers dozens of cues per
  battle, many stacked in one resolution. A cue that is long, boomy, or has a slow attack turns a
  three-hit exchange into mud. Fast attack, short tail, distinct across siblings (a hit must not be
  mistakable for a heal). Think **stylised**, not cinematic realism.
- **Music is a bed, not a song.** It loops for as long as the player lingers, so it must reward
  attention on the tenth loop and never on the first — no strong hook that becomes a nag, no obvious
  seam. Melodic-but-restrained; the hub and menu especially sit under long stretches of reading.
- **The two big fights earn their own beds.** `music.battle` is workmanlike tactical tension;
  `music.boss` is the seven generals and must feel like the wall it is. `music.credits` is the one
  authored *ending* — it plays once and stops (`loop = false`), so it can have a real close.
- **Mixing lives in data, not the file.** `data/sounds.lua` carries a per-cue `volume` trim; deliver
  each file at a consistent working loudness and let the trims balance it. Do not pre-duck a file to
  sit under the others — that bakes a mix decision into an asset that then can't be re-balanced.

## Format & delivery

- **Ogg Vorbis (`.ogg`) throughout.** It is what LÖVE decodes everywhere with no licence question,
  and its streaming path (used for music) seeks cheaply. Deliver source in a lossless master (WAV)
  if convenient, but the committed asset is `.ogg`.
- **SFX:** 44.1 kHz, mono is fine (and preferred — these are UI/battle blips, not soundscapes),
  short (see per-cue lengths below), normalised to a consistent peak with the per-cue `volume` trim
  doing the final balance.
- **Music:** 44.1 kHz stereo. **Seamless loop** — author so the tail meets the head with no click or
  gap; LÖVE loops the whole file, there are no declared loop points, so the seam must be in the audio
  itself. `music.credits` is the exception: it is `loop = false` and may end naturally.
- **Paths are fixed by the cue table.** Drop the file at exactly the path `. audio-report missing`
  prints. The report and the wiring both key off it; a differently-named file is invisible.

## The cues

Lengths and moods are targets for whoever records or sources them, not hard gates.

### Music — 6, one per place the player spends time

| path | where | length | mood |
|---|---|---|---|
| `music/menu.ogg` | title screen | 60–120 s loop | calm, inviting, sits under a still screen; the game's face |
| `music/hub.ogg` | the town / hub city | 90–150 s loop | warm, unhurried, safe; plays under long reading and shopping |
| `music/overworld.ogg` | the campaign map | 90–150 s loop | travelling, light forward motion, low tension |
| `music/battle.ogg` | ordinary battles | 60–120 s loop | tactical tension, steady pulse, never frantic |
| `music/boss.ogg` | the seven generals (objective fights) | 60–120 s loop | the wall of the run; heavier, thematic, a real antagonist |
| `music/credits.ogg` | the ending roll (`loop = false`) | 90–180 s, **ends** | resolution; the one track with an authored close |

### UI — 4, on the shared menu widget

| path | fires when | length | notes |
|---|---|---|---|
| `ui/move.ogg` | selection moves between menu items | ≤120 ms | played constantly — must be tiny and unobtrusive (trim 0.5) |
| `ui/confirm.ogg` | an item is chosen | ≤200 ms | positive, crisp |
| `ui/cancel.ogg` | back / close a panel | ≤200 ms | softer, "step back" (trim 0.8) |
| `ui/denied.ogg` | input rejected (no stamina, illegal move) | ≤250 ms | a clear "no", not harsh (trim 0.7) |

### Battle — 10, one-shot per combat event

Coarse on purpose — one hit, one death, whatever the weapon. A per-weapon layer can come later via
an item `sound` field; these are the floor that makes combat stop being silent. Siblings must be
**distinguishable**: hit ≠ heal ≠ status, crit reads as "more" than hit, miss reads as "nothing
landed."

| path | fires when | length | mood |
|---|---|---|---|
| `battle/start.ogg` | a battle begins | ≤600 ms | a curtain-up hit; the fight is on |
| `battle/hit.ogg` | damage lands | ≤250 ms | a solid connect (trim 0.8) |
| `battle/crit.ogg` | a heavy blow lands (≥12 dmg — see note above) | ≤400 ms | a bigger, brighter version of hit |
| `battle/miss.ogg` | a blow is voided (dodge / smoke / substitute) | ≤200 ms | a whiff / air, clearly "no contact" (trim 0.6) |
| `battle/death.ogg` | a unit drops to 0 HP | ≤700 ms | a fall/finality, weighty but not grim |
| `battle/heal.ogg` | healing is applied | ≤500 ms | warm, ascending, unmistakably positive (trim 0.7) |
| `battle/status.ogg` | a status or field lands on a unit | ≤500 ms | magical/shimmer, neutral (trim 0.6) |
| `battle/turn.ogg` | the active unit changes | ≤150 ms | a soft tick; plays every turn, keep tiny (trim 0.5) |
| `battle/win.ogg` | the battle is won | 1–2 s | a short victory flourish |
| `battle/loss.ogg` | the battle is lost | 1–2 s | a short, gentle defeat — bright-fantasy, not funereal |

### Quest / progress — 3, stings

| path | fires when | length | mood |
|---|---|---|---|
| `quest/complete.ogg` | an objective/quest clears | 1–2 s | the reward sting — the moment the game most obviously lacks |
| `quest/levelup.ogg` | a companion levels | 1–1.5 s | a rising, celebratory chime |
| `quest/join.ogg` | a companion joins the party (the banner) | 1–1.5 s | a warm, welcoming flourish |

## Sourcing

Two hard constraints, identical to art: **commercial use must be permitted**, and **no AI-generated
audio**.

| source | covers | terms |
|---|---|---|
| [freesound.org](https://freesound.org/) (filter **CC0**) | UI, battle SFX, stings | CC0 = no attribution needed; CC BY = attribution required |
| [OpenGameArt](https://opengameart.org/) | SFX and music | per-asset — read each; CC0 / CC BY / GPL all appear |
| [Kenney](https://kenney.nl/assets?q=audio) | UI + interface SFX packs | CC0 — clean, consistent, ideal for `ui/*` |
| commission | the 6 music beds, if a coherent original score is wanted | — |

Prefer **CC0** so the credits obligation stays as light as possible. Where a **CC BY** source is
used, it must be credited to players the same way the icons are — see below.

**Rejected on the same grounds as art:** any AI-generated pack (direction bans it), and any asset
whose licence is only "free to use" with no named terms (ambiguous terms are not a basis for
shipping — see [art-assets.md](art-assets.md#rejected-and-why)).

### Attribution

If any shipped cue is CC BY (not CC0), its author must be named on the **credits screen**, exactly as
game-icons.net is for the art ([art-assets.md](art-assets.md#attribution-obligation)). Unlike the
icon pipeline there is no generator writing an audio credits file yet; if CC BY audio is used, add
its line to the credits roll (`states/credits.lua`) at the same time the file lands, not at ship.
Keeping everything CC0 avoids this entirely.

## Priority order

Do these in order; each is playable value on its own.

1. **`quest/complete.ogg` + `music/hub.ogg` + `music/battle.ogg`.** The three the player meets first
   and most: a fight resolving with a sting, the town with a bed, a battle with a bed. Biggest
   perceived jump from "silent" for the least content.
2. **The UI set** (`ui/move`, `confirm`, `cancel`, `denied`). Cheap, high-frequency, and Kenney-style
   CC0 packs cover them well.
3. **The core battle set** (`hit`, `crit`, `miss`, `death`, `heal`, `turn`). Where the game spends its
   time.
4. **Remaining music** (`menu`, `overworld`, `boss`, `credits`) and remaining stings (`win`, `loss`,
   `status`, `levelup`, `join`).

## Adding new audio

1. The cue is already declared in `data/sounds.lua` and wired at its call site — a missing file is safe.
2. Drop the `.ogg` into the matching `assets/audio/` folder at the exact path the report prints.
3. Re-run `. audio-report` and update the snapshot table above. If CC BY, add the credit line.

A brand-new cue (a kind of event not yet listed) is a new row in `data/sounds.lua` plus a
`Sound.play`/`Sound.music` call — `tools/audio_report.lua` counts whatever the table declares, so no
change is needed there.
