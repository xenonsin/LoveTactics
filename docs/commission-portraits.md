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

- **Style: anime — in the vein of _Fire Emblem_ (Awakening / Three Houses) and _Granblue
  Fantasy_.** Clean confident line, bright fantasy palette, expressive faces, and the polished,
  softly-rendered painting those two are known for (Granblue's rich cloth/armour rendering over
  Fire Emblem's readable heroic silhouettes). **Not pixel art** — paint above final size and
  downscale.
- **Full standing figure**, visual-novel framing — head to (at least) mid-thigh, readable as a
  person leaning into frame, not a floating bust.
- **One consistent cast.** Same rendering style, proportions, and **head height** across all 24 —
  they share screen space side by side, and an outsized head on one throws the whole line off.
- **Human-made only:** **no AI-generated content** — a contractual requirement, not a preference.

## Technical spec

- **Deliver ≥ 1400 px tall** per portrait — displayed at 470px, but authored large so it stays sharp
  at any future card or panel size.
- **Displayed at 470px tall**, anchored **bottom-centre** — the figure's feet rest just inside the
  top edge of the text box (`ui/dialogue.lua`, `PORTRAIT_H = 470`). It is also drawn as a **side
  bust** rising over the box's right end, VN-speaker style. Compose so the figure reads both full
  and cropped to the upper body.
- **Active vs inactive tint:** the speaking portrait is full colour; others are **greyed (a dark
  multiply)**. Art must still read when darkened — avoid relying on subtle low-contrast detail.
- **Delivery:** transparent PNG, named to match the file list below. A layered source (PSD) is
  welcome but not required.

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
| `general_wrath.png` | **Ira, the Unappeased** | Wrath | The house's manufactured champion; owned all her life, sullen wrath held down, wanting only to be free. |
| `general_sloth.png` | **Acedia, the Unrelieved** | Sloth | The gatekeeper who "opened the gate"; imposes a false unity. |
| `general_pride.png` | **Sublimitas, the Unequalled** | Pride | Untouchable, above all comers. |
| `general_lust.png` | **Luxuria, the Unbidden** | Lust | A human-pacted demon-Saint. |
| `general_greed.png` | **Aurea, the Ever-Owed** | Greed | Everything is owed to her. |
| `general_gluttony.png` | **Gula, the Unsated** | Gluttony | Never full; aggressive, devouring. |
| `general_envy.png` | **Livia, the Unborn** | Envy | A homunculus who pacted to become human. |

### The eight vendors — shopkeepers
One VN portrait each, for the shop's proprietor. Seven are themed to a sin (their quest line ends
facing that general); the Cafe is the neutral road-store. Files match the vendor id
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
| `cafe.png` | **The Cafe** | — (neutral) | Everything the road needs and nothing the temple sells. |

### The final boss
| File | Name | Notes |
|---|---|---|
| `demon_lord.png` | **The Hollow Crown** | The Demon Lord — the end of everything the seven ladders counted toward. The seven sins were its appetites, taken off it one at a time; it wears the dead generals as it fails (`data/characters/character_demon_lord.lua`). An imposing, hollowed sovereign. |

## The on-board unit art is a separate commission

The animated sprites that stand on the tactics grid — for the whole cast **and** the named enemies —
are **not** part of this portrait brief. They are hand-rigged in Spine and specified separately in
[commission-board-sprites.md](commission-board-sprites.md). These portraits serve the dialogue box
only.

## Scope & phasing (suggested)

- **Phase 1 — the party**: `avatar_1` (+ gender variant) and the seven companions (Rowan, Saber,
  Kaya, Gyeom, Amana, Ren, Clem) — the faces the player sees most.
- **Phase 2 — the vendors (8)** — the shopkeepers the player meets every town visit.
- **Phase 3 — the antagonists**: the seven generals + the Demon Lord — the story's payoff.

## Licensing

**Full commercial rights / work-for-hire buyout** — use in a commercial game and its marketing, no
project-count limit. **100% human-authored, no AI-generated content.** Credit welcome, not required.
