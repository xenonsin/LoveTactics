# Audio commission list

> **Generated** from [../data/sounds.lua](../data/sounds.lua) by `& "E:\LOVE\love.exe" . audio-commission` (use `lovec.exe` for console output). **Do not hand-edit** -- change a cue's `length`/`desc` in `data/sounds.lua` and regenerate. Direction, format, sourcing and the on-disk count live in [audio-assets.md](audio-assets.md) (and `. audio-report`).

**48 cues** across 5 buckets. Each row is one sound to source or record; `Trim` is the in-engine mix level (blank = full), applied on top of a file delivered at a consistent working loudness.

## music — 8

Streamed, looping beds -- one per place the player spends time. Seamless loops (tail meets head, no click); 44.1kHz stereo. `music.credits` is the one that ENDS.

| Cue | File | Length | Trim | Brief |
|---|---|---|---|---|
| `music.battle` | `assets/audio/music/battle.ogg` | 60-120s loop |  | Ordinary battles. Tactical tension, steady pulse, never frantic. |
| `music.boss` | `assets/audio/music/boss.ogg` | 60-120s loop |  | The seven generals / objective fights. The wall of the run -- heavier, thematic, a real antagonist. |
| `music.credits` | `assets/audio/music/credits.ogg` | 90-180s, ENDS |  | The ending roll. Resolution -- the one track with an authored close; plays once and stops. |
| `music.defeat` | `assets/audio/music/defeat.ogg` | 40-90s loop | 0.8 | Plays the instant a fight is lost, under the grey defeat panel. Subdued, mournful but not crushing -- the run is over; loops quietly while the player decides to retry or return. |
| `music.hub` | `assets/audio/music/hub.ogg` | 90-150s loop | 0.8 | The town / hub city. Warm, unhurried, safe -- plays under long reading and shopping. |
| `music.menu` | `assets/audio/music/menu.ogg` | 60-120s loop | 0.8 | Title screen. Calm, inviting, sits under a still screen -- the game's face. |
| `music.overworld` | `assets/audio/music/overworld.ogg` | 90-150s loop | 0.8 | The campaign map. Travelling, light forward motion, low tension. |
| `music.victory` | `assets/audio/music/victory.ogg` | 40-90s loop | 0.8 | Plays the instant a fight is won, under the spoils panel. Warm, triumphant, unhurried -- the exhale after the battle bed; loops while the player reads the reward and the log. |

## ui — 5

The shared menu widget (mouse/keyboard/gamepad). Modelled on classic Final Fantasy menus: clean synth blips, not clicks. Mono, 44.1kHz.

| Cue | File | Length | Trim | Brief |
|---|---|---|---|---|
| `ui.cancel` | `assets/audio/ui/cancel.ogg` | <=0.25s | 0.8 | Back out / close a panel, or cancel a selected item in battle. A softer, lower bell -- a mellow 'step back'. (FF/KH cancel.) |
| `ui.confirm` | `assets/audio/ui/confirm.ogg` | <=0.25s |  | An item is chosen / an action committed in a menu. A warm, bright bell chime -- positive but soft, never sharp. (FF/KH confirm.) |
| `ui.denied` | `assets/audio/ui/denied.ogg` | <=0.3s | 0.7 | Input refused (no stamina, an illegal move). A soft, muted low 'no' -- rounded and clearly negative, never a harsh buzzer. (FF/KH error.) |
| `ui.move` | `assets/audio/ui/move.ogg` | <=0.15s | 0.5 | Cursor moves between menu items. Plays constantly, so soft, short and unobtrusive -- a gentle bell blip, warm, no click. (FF/KH cursor.) |
| `ui.type` | `assets/audio/ui/type.ogg` | <=0.08s | 0.35 | The typewriter tick under a conversation's text reveal (ui/dialogue.lua). Fires per few characters as a line types out, so it must be TINY and dry -- a soft rounded blip / key-tap, no pitch tail; a whole line is a run of these. Slightly pitch-varied at the call site. (FE/Undertale text blip.) |

## battle — 30

One-shot per combat event, including the 11 damage-type impacts. Short and readable -- the player triggers dozens per fight, often stacked. Mono, 44.1kHz.

| Cue | File | Length | Trim | Brief |
|---|---|---|---|---|
| `battle.buff` | `assets/audio/battle/buff.ogg` | <=0.5s | 0.6 | A beneficial status lands (a blessing, a ward, a stat-up). Bright, rising, 'I was helped'. |
| `battle.cast` | `assets/audio/battle/cast.ogg` | <=0.3s | 0.5 | An OFFENSIVE ability activates -- the swing under an attack's impact, or a spell being loosed. A whoosh / release; support casts stay silent and let heal/buff speak. |
| `battle.channel` | `assets/audio/battle/channel.ogg` | <=0.7s | 0.6 | A powerful spell BEGINS winding up -- a channel/telegraph goes up (Meteor Storm and the like), on either side. A rising, building arcane charge; ominous, promising something big lands soon. |
| `battle.confirm` | `assets/audio/battle/confirm.ogg` | <=0.2s | 0.6 | The player COMMITS an action (move/attack/ability). Crisp, decisive -- distinct from the menu confirm, and it precedes the cast/step/hit the action makes. |
| `battle.crit` | `assets/audio/battle/crit.ogg` | <=0.4s |  | A heavy UNTYPED blow (>=12 dmg). A bigger, brighter version of hit -- the fallback when a big blow has no damage type of its own. |
| `battle.death` | `assets/audio/battle/death.ogg` | <=0.7s |  | A unit drops to 0 HP. A fall / finality, weighty but not grim. |
| `battle.debuff` | `assets/audio/battle/debuff.ogg` | <=0.5s | 0.6 | A harmful status lands (Burn, Stun, Root, a stat-down). Darker, lower, 'something's wrong'. |
| `battle.heal` | `assets/audio/battle/heal.ogg` | <=0.5s | 0.7 | Healing is applied. Warm, ascending, unmistakably positive. |
| `battle.hit` | `assets/audio/battle/hit.ogg` | <=0.25s | 0.8 | The GENERIC impact of a surviving blow, when its damage type has no cue of its own (see the hit_* block). A solid connect. |
| `battle.hit_acid` | `assets/audio/battle/hit_acid.ogg` | <=0.35s | 0.7 | Acid damage. A corrosive SIZZLE -- high fizzing hiss, caustic, a little nasty. |
| `battle.hit_dark` | `assets/audio/battle/hit_dark.ogg` | <=0.4s | 0.7 | Dark / shadow damage. A low, ominous WHUMP -- dull sub-heavy hit with a dissonant edge. |
| `battle.hit_fire` | `assets/audio/battle/hit_fire.ogg` | <=0.35s | 0.7 | Fire damage. A whooshing IGNITE / burst of flame -- filtered-noise roar with a soft attack. |
| `battle.hit_holy` | `assets/audio/battle/hit_holy.ogg` | <=0.4s | 0.7 | Holy / radiant damage. A bright, ringing CHIME -- a clean consonant bell, warm and pure. |
| `battle.hit_ice` | `assets/audio/battle/hit_ice.ogg` | <=0.35s | 0.7 | Ice damage. A crystalline FREEZE / shatter -- a high glassy ping with a brittle crack. |
| `battle.hit_impact` | `assets/audio/battle/hit_impact.ogg` | <=0.35s | 0.8 | Impact damage (maces, hammers, fists, blunt). A heavy dull THUD -- no edge, all mass. |
| `battle.hit_lightning` | `assets/audio/battle/hit_lightning.ogg` | <=0.3s | 0.7 | Lightning damage. A sharp ZAP / crackle -- fast transient, electric snap, quick decay. |
| `battle.hit_pierce` | `assets/audio/battle/hit_pierce.ogg` | <=0.3s | 0.8 | Pierce damage (spears, arrows, daggers, a stab). A sharp DRIVE / thock -- point going in. |
| `battle.hit_poison` | `assets/audio/battle/hit_poison.ogg` | <=0.35s | 0.7 | Poison / nature damage. A wet BLURP / hiss -- bubbling, organic, faintly sickly. |
| `battle.hit_slash` | `assets/audio/battle/hit_slash.ogg` | <=0.3s | 0.8 | Slash damage (swords, axes, claws, a bite). A clean edged CUT -- a swish into a shk. |
| `battle.hit_water` | `assets/audio/battle/hit_water.ogg` | <=0.35s | 0.7 | Water damage. A SPLASH / gush -- a burst of water, mid-bright, quick to settle. |
| `battle.loss` | `assets/audio/battle/loss.ogg` | 1-2s |  | The battle is lost. A short, GENTLE defeat -- bright-fantasy, not funereal. |
| `battle.miss` | `assets/audio/battle/miss.ogg` | <=0.2s | 0.6 | A blow is voided outright -- dodged, smoked, substituted. A whiff / air, clearly 'no contact'. |
| `battle.playerturn` | `assets/audio/battle/playerturn.ogg` | <=0.4s | 0.7 | Control returns to the PLAYER -- more present than the tick above, so the player HEARS their turn begin. A short, inviting chime. |
| `battle.select` | `assets/audio/battle/select.ogg` | <=0.15s | 0.6 | The player SELECTS (arms) an ability. A light, positive pick blip. |
| `battle.start` | `assets/audio/battle/start.ogg` | <=0.6s |  | A battle begins. A curtain-up hit -- the fight is on. |
| `battle.status` | `assets/audio/battle/status.ogg` | <=0.5s | 0.6 | A condition lands, valence UNKNOWN -- the fallback when the view can't tell buff from debuff. Magical / shimmer, neutral. |
| `battle.step` | `assets/audio/battle/step.ogg` | <=0.2s | 0.4 | One footstep, played once PER TILE a unit walks (either side). Must be tiny -- a whole route is a run of these. |
| `battle.turn` | `assets/audio/battle/turn.ogg` | <=0.15s | 0.5 | The active unit changes to a NON-player unit (an enemy, an inert summon). A soft, neutral tick -- plays every enemy turn, so keep it tiny. |
| `battle.wait` | `assets/audio/battle/wait.ogg` | <=0.25s | 0.6 | The unit WAITS / holds its turn (wait, focus, defend or overwatch). A soft, calm, neutral pass -- not a commit, not a refusal; a settled 'hold'. |
| `battle.win` | `assets/audio/battle/win.ogg` | 1-2s |  | The battle is won. A short, bright victory flourish. |

## quest — 3

Progress stings -- the moments the game marks. Mono, 44.1kHz.

| Cue | File | Length | Trim | Brief |
|---|---|---|---|---|
| `quest.complete` | `assets/audio/quest/complete.ogg` | 1-2s |  | An objective / quest clears. THE reward sting -- the moment the game most wants to celebrate. |
| `quest.join` | `assets/audio/quest/join.ogg` | 1-1.5s |  | A companion joins the party (the join banner). A warm, welcoming flourish. |
| `quest.levelup` | `assets/audio/quest/levelup.ogg` | 1-1.5s |  | A companion levels up. A rising, celebratory chime. |

## treasure — 2

| Cue | File | Length | Trim | Brief |
|---|---|---|---|---|
| `treasure.open` | `assets/audio/treasure/open.ogg` | <=0.5s | 0.8 | The player presses Open on a treasure chest and the lid swings up. A wooden creak + metal latch/clasp giving way -- the chest is being opened, before the payoff. |
| `treasure.reveal` | `assets/audio/treasure/reveal.ogg` | 1-1.5s |  | The chest lid pops fully open on a burst of light and a spray of coins. THE treasure payoff -- a bright, sparkling flourish with a shimmer of falling gold; celebratory but shorter than quest.complete. |

