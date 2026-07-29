# Portraits — Commission Brief

A hand-off brief for commissioning the game's character portraits. Built from the engine's real
constraints (`ui/dialogue.lua`, `data/characters/*.lua`) and the existing plan in
[art-assets.md](art-assets.md), so delivered art drops straight in. Deep character context lives in
[story.md](story.md).

## The project

**LoveTactics** — a 2D tactics RPG built in LÖVE2D. Tone: **bright heroic fantasy** (not
grim-dark). Story is told visual-novel style: **full standing portraits** stand along the bottom of
a dialogue box and lean in over it as the speaker (à la Fire Emblem support scenes).

## Art direction

- **Style: anime.** Bright fantasy palette, clean line, expressive faces. **Not pixel art** —
  paint above final size and downscale.
- **Full standing figure**, visual-novel framing — head to (at least) mid-thigh, readable as a
  person leaning into frame, not a floating bust.
- **One consistent cast.** Same rendering style, proportions, and **head height** across all 24 —
  they share screen space side by side, and an outsized head on one throws the whole line off.
- **Human-made only:** **no AI-generated content** — a contractual requirement, not a preference.

## Technical spec

- **Deliver ≥ 1400 px tall** per portrait (displayed at 470px, but the head crop must stay sharp at
  future card sizes — see below).
- **Displayed at 470px tall**, anchored **bottom-centre** — the figure's feet rest just inside the
  top edge of the text box (`ui/dialogue.lua`, `PORTRAIT_H = 470`). It is also drawn as a **side
  bust** rising over the box's right end, VN-speaker style. Compose so the figure reads both full
  and cropped to the upper body.
- **Active vs inactive tint:** the speaking portrait is full colour; others are **greyed (a dark
  multiply)**. Art must still read when darkened — avoid relying on subtle low-contrast detail.
- **Delivery:** transparent PNG, named to match the file list below, **plus a layered source (PSD)
  or a marked square crop guide** so head crops can be re-cut without coming back to you.

### ⭐ The head crop is load-bearing

Each portrait's **head** is cropped square and reused as the character's **board token** (the
`assets/chars/` sprite on the tactics grid). This is the single most important constraint:

- **Leave headroom above the crown**, and keep **weapons, props, and hair-wings clear of the face**
  — a square crop around the head will catch anything that crosses it.
- Keep **head height consistent** cast-wide, so tokens scale to a uniform size on the board.
- The layered file / crop guide above exists so this crop can be pulled cleanly.

## The cast (24)

Files go in `assets/portraits/`. Names are the in-game names; see [story.md](story.md) for full
character notes. The seven **companions** are virtues that foil the seven **generals** (sins); the
eight **vendors** are the shopkeepers of the town's shops; the **Demon Lord** is the final boss.

> **The party is the companions — there are no generic class portraits.** The mage / archer /
> priest party roles are filled by named companions (**Gyeom** the mage, **Kaya** the hunter,
> **Amana** the priest), so no generic `mage.png` / `archer.png` / `priest.png` is commissioned.
> Retiring those generic blueprints in-game is a separate code task (see the note at the end).

### Protagonist
| File | Name | Notes |
|---|---|---|
| `avatar_1.png` | **Stranger** | The player's created avatar — sole survivor of a burning village, a blank-slate hero, nameless until the Colosseum names them. **Gender is chosen at creation** (`avatar_<n>`), so plan for **≥2 variants** (e.g. `avatar_1` / `avatar_2`), matched in style. |

### Companions — the seven virtues
| File | Name | Role / read |
|---|---|---|
| `knight.png` | **Rowan** | The knight — bodyguard & mentor; steadfast, patient. Front-line guard. |
| `saber.png` | **Saber** | The gladiator — virtue *patience*; principled ("won't kill those who can't choose"). |
| `kaya.png` | **Kaya** | The hunter — virtue *temperance* ("enough"); ranged, measured. |
| `gyeom.png` | **Gyeom** | The mage — arcane skirmisher. |
| `amana.png` | **Amana** | The priest/acolyte — support/healer (Cathedral line). |
| `ren.png` | **Ren** | The alchemist — kindness; mends before she strikes (Crucible line). |
| `clem.png` | **Clem** | The rogue — aggressive glass-cannon skirmisher. |

### The seven generals — personified sins (Latin register; all women)
| File | Name | Sin | Read |
|---|---|---|---|
| `general_wrath.png` | **Ira, the Unappeased** | Wrath | Blind from birth, raised into numbness, handed one feeling — rage. |
| `general_sloth.png` | **Acedia, the Unrelieved** | Sloth | The gatekeeper who "opened the gate"; imposes a false unity. |
| `general_pride.png` | **Sublimitas, the Unequalled** | Pride | Untouchable, above all comers. |
| `general_lust.png` | **Luxuria, the Unbidden** | Lust | A human-pacted demon-Saint. |
| `general_greed.png` | **Aurea, the Ever-Owed** | Greed | Everything is owed to her. |
| `general_gluttony.png` | **Gula, the Unsated** | Gluttony | Never full; aggressive, devouring. |
| `general_envy.png` | **Livia, the Unborn** | Envy | A homunculus who pacted to become human. |

### The eight vendors — shopkeepers
One VN portrait each, for the shop's proprietor. Seven are themed to a sin (their quest line ends
facing that general); the Market is the neutral road-store. Files match the vendor id
(`data/vendors/*.lua`).

| File | Shop | Sin | The shop's read |
|---|---|---|---|
| `colosseum.png` | **The Colosseum** | Wrath | Blood, sand, a roaring crowd; the masters sell what wins fights. |
| `bastion.png` | **The Bastion** | Sloth | An order that measures a knight by what they refused to abandon. |
| `cathedral.png` | **The Cathedral** | Lust | Cold stone and colder certainty; the faithful arm those who purge. |
| `alchemist.png` | **The Crucible** | Envy | Every jar is labelled with something else's name. |
| `arcanum.png` | **The Arcanum** | Pride | A library that has outlived every scholar who swore he could read it safely. |
| `undercroft.png` | **The Undercroft** | Greed | No sign, no door you'd notice; everything inside belonged to someone else. |
| `hunters_lodge.png` | **Hunter's Lodge** | Gluttony | Antlers on every beam; they ask what you killed before your name. |
| `market.png` | **The Market** | — (neutral) | Everything the road needs and nothing the temple sells. |

### The final boss
| File | Name | Notes |
|---|---|---|
| `demon_lord.png` | **The Hollow Crown** | The Demon Lord — the end of everything the seven ladders counted toward. The seven sins were its appetites, taken off it one at a time; it wears the dead generals as it fails (`data/characters/character_demon_lord.lua`). An imposing, hollowed sovereign. |

## Related: enemy heads (9) — a separate, later deliverable

Not part of the 24 above. Nine named enemies need **square busts only (~512px)**, in the **same
style and head scale** as the cast — so they sit consistently on the board. These aren't pinned yet;
scope them from the boss roster when this phase starts (see [art-assets.md](art-assets.md)).

## Scope & phasing (suggested)

- **Phase 1 — the party**: `avatar_1` (+ gender variant) and the seven companions (Rowan, Saber,
  Kaya, Gyeom, Amana, Ren, Clem) — the faces the player sees most, and the fastest proof of the
  load-bearing head crop working as a board token.
- **Phase 2 — the vendors (8)** — the shopkeepers the player meets every town visit.
- **Phase 3 — the antagonists**: the seven generals + the Demon Lord — the story's payoff.

## Code follow-ups (so the game and the report agree)

- **Retire the generic classes — done.** The player already starts lean (a New Game resets to just
  the avatar, then Rowan is sworn in the prologue; the rest are recruited at slot 2 of each vendor
  line), so `data/player.lua`'s default roster/party is now `character_rowan` only, and the
  `portrait` field was stripped from `character_mage` / `character_archer` / `character_priest`.
  Those blueprints are **kept** — they're load-bearing enemy/ally/test stand-ins across ~15 quests
  and ~60 tests (e.g. `win = { assassinate, target = character_priest }`, `allies = { character_priest }`),
  where a companion would make no sense — but they no longer appear in the party or owe a portrait.
- **Wire the new portraits (still to do)** — add `portrait = "assets/portraits/<id>.png"` to the
  seven other `data/vendors/*.lua` and to `character_demon_lord.lua`, so `art-report` counts them
  and the VN box can show them.

After the vendor/boss wiring, `& "E:\LOVE\lovec.exe" . art-report` will list exactly these 24
portrait files (the three generic `mage`/`archer`/`priest` portraits are already gone from it).

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored, no AI-generated content.** Credit welcome, not required.
