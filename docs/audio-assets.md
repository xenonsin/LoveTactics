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

As of 2026-07-29 — **43 of 46 present**, 3 outstanding. Regenerate with the command above.
Each cue in [../data/sounds.lua](../data/sounds.lua) carries a one-line commission spec above it — that
file is the brief; this doc is the counts and the sourcing.

| bucket | have | needed | plays through |
|---|---|---|---|
| `music/` | 5 | 6 | `Sound.music(id)` — streamed, looped bed (one per place the player spends time) |
| `ui/` | 4 | 4 | `Sound.play(id)` — the shared menu widget (FF-style synth blips) |
| `battle/` | 30 | 30 | `Sound.play(id)` — one-shot per combat event, incl. 11 damage-type impacts |
| `quest/` | 3 | 3 | `Sound.play(id)` — progress stings |
| `treasure/` | 0 | 2 | `Sound.play(id)` — the chest-opening loot reveal (unlatch + payoff pop) |

**The split is: music is sourced, every other cue is a synthesized placeholder.** The five present
music beds use real sourced (CC0) tracks; all SFX and stings are synthesized stand-ins (deterministic
DSP, licence-free) until real ones are recorded or sourced. **`music.boss` is intentionally absent**:
boss/objective fights run without a bed (ordinary battles use the sourced `battle` track; the Mock
Battle asks for it too via `encounter.music`, since it is objective-kind but not a boss). Every cue
stays declared and wired, so a real file dropped at any path starts playing with no code change — the
one outstanding item above is `music.boss`, by choice.

The `battle/` bucket grew from 10 to 30. The action-loop and turn cues: **playerturn** (control returns
to the player, distinct from the neutral **turn** tick), **select** (arm an ability), **confirm**
(commit an action), **wait** (hold the turn — wait/focus/defend/overwatch), **cast** (an offensive
activation — the swing under an attack's impact, or an ability firing; support casts stay silent and
let their heal/buff cue speak), **channel** (a powerful spell begins winding up — a telegraph goes up,
either side), **step** (one footstep per tile walked), and **buff** / **debuff** (a condition landing,
split by valence — the view reads `def.debuff`, falling back to the neutral **status** cue when it
can't tell). Wired in [models/combat.lua](../models/combat.lua) (channel), [states/battle.lua](battle.lua)
and [ui/combat_fx.lua](combat_fx.lua), pinned by `tests/audio_wiring_spec.lua`.

The other 11 are **damage-type impacts** — `battle.hit_<motif>` for slash, pierce, impact, fire, ice,
lightning, holy, dark, poison, water, acid. [ui/combat_fx.lua](combat_fx.lua) `playHit` reads
`Motif.of(tags)` — the *same* element reading the impact burst uses ([ui/motif.lua](motif.lua)) — so a
blow's sound and its burst always name one element; a blow whose type has no cue falls back to the
generic `battle.hit`/`battle.crit`. A heavy typed blow rings its own cue pitched down, so it still
reads as "more". A **critical** outranks the element and rings `battle.crit` outright — the dice are
the more urgent fact, and a fire crit that sounded exactly like a fire hit would only be legible from
the number.

The whole system (roadmap items 4–7) is built: `models/sound.lua`, `data/sounds.lua`,
`. audio-report`, and persisted master/music/effects volumes in the settings screen. **A first-pass
CC0 fill now backs every cue** (roadmap item 8) — see [First-pass fill](#first-pass-fill) for what
each cue is and how to swap it. Every file lives in the gitignored `assets/` (like all other art
buckets), so it is local-only and never committed.

## First-pass fill

Every cue is backed by a placeholder — **all SFX/stings are synthesized** (ffmpeg DSP, licence-free)
and the **music beds are sourced CC0 tracks**. Nothing owes attribution (synth is original; the music
is CC0), so nothing was added to the credits roll. Each file is mono 44.1 kHz (SFX) or stereo 44.1 kHz
(music) at its cue path; a better file at the same path replaces it with no code change. The synth SFX
were tuned by construction, not by ear (they can't be auditioned here), so they are rough stand-ins —
worth a listen and an easy retune/swap.

| source | covers |
|---|---|
| **Synthesized** (ffmpeg lavfi — deterministic DSP, not AI, no licence) | EVERY non-music cue — all `ui/*` (FF/KH-style soft bells); all `battle/*` (impacts, whooshes, shimmers, stings, the 11 damage-type hits); all `quest/*` stings |
| [RandomMind — *Medieval:* series](https://opengameart.org/users/randommind) (OpenGameArt, CC0) | `music/menu` (Harvest Season) `hub` (Market Day, purpose-made loop) `overworld` (Exploration) `credits` (Victory Theme) |
| [Emma_MA — QaziJamJam (orchestral battle theme)](https://opengameart.org/content/qazijamjam-orchestral-battle-theme) (OpenGameArt, CC0) | `music/battle` — orchestral, strings/brass/woodwinds/drums |
| _(none yet)_ | `music/boss` — pulled for now; boss/objective fights run silent until a track lands |

The synthesized SFX are built from a few recipes: **impacts** (hit/crit/hit_impact) are a filtered
noise burst over a short pitched body; **cuts/whooshes** (slash, pierce, miss, cast, step) are
enveloped band/low/high-passed noise; **death/start** are pitch sweeps (down / up) over noise;
**shimmers, ticks and stings** (status, buff/debuff, turn, heal, win/loss, quest/*) are soft sine-bell
arpeggios with exponential decay; the **8 elemental hits** and the arcane **channel** riser use the
same noise/sweep toolkit. All deliberately simple stand-ins — swap any for a real file at its path.

The music (sourced) is seamless where the source ships a purpose-cut loop (RandomMind's Market Day,
Epic Combat is tagged loopable); `music/menu` and `music/overworld` loop a full track, so a musical
(not clicky) seam is possible — flagged for a future pass.

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

Both of these cues used to be wired to the nearest real signal rather than the mechanic their name
suggests, because that mechanic did not exist in this engine. **It does now** — see
[accuracy.md](accuracy.md) — and each cue fires for the thing it is named after:

- **`battle.crit`** — a real critical hit (`Combat.critChance`, a weapon's crit plus half the
  swinger's skill, less the target's luck). A crit takes this cue even when the blow carries an
  element, because "that was a critical" is the thing the player most needs to hear. The old
  heavy-blow rule survives underneath it: an ordinary untyped blow of ≥12 still rings this as the
  punchier `battle.hit`, which is what the cue was doing on its own before.
- **`battle.miss`** — a failed hit roll, which is now the most common thing that happens to an
  attack. It still also marks a blow **voided** outright by a dodge, a smoke charge or a substitution
  clone; those were the only ways to reach it before. Because a miss went from rare to routine, the
  view no longer leaves it to the speakers — it floats a readable **MISS** on the struck tile and
  holds the turn hand-off while it climbs, exactly as a damage number does.

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
- **The decided fight swaps beds.** The moment a battle is won or lost the tactical bed gives way:
  `music.victory` is the warm exhale under the spoils panel, `music.defeat` the subdued bed under the
  grey. Both still loop while the player lingers on the summary — an outcome, not an authored ending.
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

The full per-cue list — every sound, its file, target length, mix trim and a one-line brief — is a
**generated document**, [audio-commission.md](audio-commission.md), so it can never drift from what
the game actually asks for. The spec lives on each cue as `length`/`desc` fields in
[../data/sounds.lua](../data/sounds.lua); regenerate the doc after changing them:

```powershell
& "E:\LOVE\lovec.exe" . audio-commission     # writes docs/audio-commission.md from data/sounds.lua
```

Adding a cue without a `length`+`desc` fails `tests/sound_spec.lua`, so the brief is complete by
construction — a cue nobody can source cannot be added. Lengths and moods there are targets for
whoever records or sources them, not hard gates.

Two things worth keeping in mind that the generated table does not spell out:

- **Battle siblings must be distinguishable**: hit ≠ heal ≠ status, buff ≠ debuff, crit reads as
  "more" than hit, miss reads as "nothing landed."
- **Damage-type impacts** (`battle.hit_<element>`) are chosen by the blow's element the same way the
  impact burst is ([ui/motif.lua](../ui/motif.lua)), so a blow's sound and its picture always agree;
  a type with no cue of its own falls back to the generic `battle.hit`.

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
