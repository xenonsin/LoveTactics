-- The cue table: every sound the game can ask for, declared as data.
--
-- This file is the audio equivalent of a blueprint's `sprite` field, and it exists for the same
-- reason art paths live in data rather than in the drawing code: the roster of sounds the game wants
-- has to be READABLE and COUNTABLE without running it. `. audio-report` walks this table against what
-- is on disk and prints the debt; `. audio-commission` turns it into docs/audio-commission.md, the
-- brief an audio author works from -- exactly as `. art-report` and docs/art-assets.md do for images.
--
-- models/sound.lua resolves a missing file to silence, so every cue below is already wired at its call
-- site, already does nothing, and starts making noise the moment an .ogg lands at the path it names.
--
-- A cue is `{ file, category, volume, loop, length, desc }`:
--   file     -- where the audio lives / will live.
--   category -- "sfx" or "music"; picks which volume preference scales it (models/sound.lua).
--   volume   -- optional per-cue trim, 0..1, for a cue that is simply too loud against the rest.
--   loop     -- music only; defaults to true for a bed, set false for a one-shot sting.
--   length   -- the COMMISSION target length (a string, for docs/audio-commission.md).
--   desc     -- the COMMISSION brief: what the sound is, when it fires, the character it wants.
--
-- `length` and `desc` are the commission spec: they are DATA (not comments) so `. audio-commission`
-- can generate the brief from this one table and it can never drift from what the game actually asks
-- for. Adding a cue without them fails tests/sound_spec.lua -- a cue with no brief is a cue nobody can
-- source. Ogg Vorbis throughout. Naming is `<area>.<thing>`.
return {
    -- UI -- the shared menu widget (ui/menu.lua). Modelled on classic Final Fantasy menus: clean synth
    -- blips, not clicks.
    ["ui.move"] = { file = "assets/audio/ui/move.ogg", category = "sfx", volume = 0.5,
        length = "<=0.15s", desc = "Cursor moves between menu items. Plays constantly, so soft, short and unobtrusive -- a gentle bell blip, warm, no click. (FF/KH cursor.)" },
    ["ui.confirm"] = { file = "assets/audio/ui/confirm.ogg", category = "sfx",
        length = "<=0.25s", desc = "An item is chosen / an action committed in a menu. A warm, bright bell chime -- positive but soft, never sharp. (FF/KH confirm.)" },
    ["ui.cancel"] = { file = "assets/audio/ui/cancel.ogg", category = "sfx", volume = 0.8,
        length = "<=0.25s", desc = "Back out / close a panel, or cancel a selected item in battle. A softer, lower bell -- a mellow 'step back'. (FF/KH cancel.)" },
    ["ui.denied"] = { file = "assets/audio/ui/denied.ogg", category = "sfx", volume = 0.7,
        length = "<=0.3s", desc = "Input refused (no stamina, an illegal move). A soft, muted low 'no' -- rounded and clearly negative, never a harsh buzzer. (FF/KH error.)" },

    -- Battle flow -- one-shot per combat event (states/battle.lua, ui/combat_fx.lua).
    ["battle.start"] = { file = "assets/audio/battle/start.ogg", category = "sfx",
        length = "<=0.6s", desc = "A battle begins. A curtain-up hit -- the fight is on." },
    ["battle.win"] = { file = "assets/audio/battle/win.ogg", category = "sfx",
        length = "1-2s", desc = "The battle is won. A short, bright victory flourish." },
    ["battle.loss"] = { file = "assets/audio/battle/loss.ogg", category = "sfx",
        length = "1-2s", desc = "The battle is lost. A short, GENTLE defeat -- bright-fantasy, not funereal." },
    ["battle.hit"] = { file = "assets/audio/battle/hit.ogg", category = "sfx", volume = 0.8,
        length = "<=0.25s", desc = "The GENERIC impact of a surviving blow, when its damage type has no cue of its own (see the hit_* block). A solid connect." },
    ["battle.crit"] = { file = "assets/audio/battle/crit.ogg", category = "sfx",
        length = "<=0.4s", desc = "A heavy UNTYPED blow (>=12 dmg). A bigger, brighter version of hit -- the fallback when a big blow has no damage type of its own." },
    ["battle.miss"] = { file = "assets/audio/battle/miss.ogg", category = "sfx", volume = 0.6,
        length = "<=0.2s", desc = "A blow is voided outright -- dodged, smoked, substituted. A whiff / air, clearly 'no contact'." },
    ["battle.death"] = { file = "assets/audio/battle/death.ogg", category = "sfx",
        length = "<=0.7s", desc = "A unit drops to 0 HP. A fall / finality, weighty but not grim." },
    ["battle.heal"] = { file = "assets/audio/battle/heal.ogg", category = "sfx", volume = 0.7,
        length = "<=0.5s", desc = "Healing is applied. Warm, ascending, unmistakably positive." },
    ["battle.status"] = { file = "assets/audio/battle/status.ogg", category = "sfx", volume = 0.6,
        length = "<=0.5s", desc = "A condition lands, valence UNKNOWN -- the fallback when the view can't tell buff from debuff. Magical / shimmer, neutral." },
    ["battle.buff"] = { file = "assets/audio/battle/buff.ogg", category = "sfx", volume = 0.6,
        length = "<=0.5s", desc = "A beneficial status lands (a blessing, a ward, a stat-up). Bright, rising, 'I was helped'." },
    ["battle.debuff"] = { file = "assets/audio/battle/debuff.ogg", category = "sfx", volume = 0.6,
        length = "<=0.5s", desc = "A harmful status lands (Burn, Stun, Root, a stat-down). Darker, lower, 'something's wrong'." },
    ["battle.turn"] = { file = "assets/audio/battle/turn.ogg", category = "sfx", volume = 0.5,
        length = "<=0.15s", desc = "The active unit changes to a NON-player unit (an enemy, an inert summon). A soft, neutral tick -- plays every enemy turn, so keep it tiny." },
    ["battle.playerturn"] = { file = "assets/audio/battle/playerturn.ogg", category = "sfx", volume = 0.7,
        length = "<=0.4s", desc = "Control returns to the PLAYER -- more present than the tick above, so the player HEARS their turn begin. A short, inviting chime." },
    ["battle.select"] = { file = "assets/audio/battle/select.ogg", category = "sfx", volume = 0.6,
        length = "<=0.15s", desc = "The player SELECTS (arms) an ability. A light, positive pick blip." },
    ["battle.confirm"] = { file = "assets/audio/battle/confirm.ogg", category = "sfx", volume = 0.6,
        length = "<=0.2s", desc = "The player COMMITS an action (move/attack/ability). Crisp, decisive -- distinct from the menu confirm, and it precedes the cast/step/hit the action makes." },
    ["battle.wait"] = { file = "assets/audio/battle/wait.ogg", category = "sfx", volume = 0.6,
        length = "<=0.25s", desc = "The unit WAITS / holds its turn (wait, focus, defend or overwatch). A soft, calm, neutral pass -- not a commit, not a refusal; a settled 'hold'." },
    ["battle.cast"] = { file = "assets/audio/battle/cast.ogg", category = "sfx", volume = 0.5,
        length = "<=0.3s", desc = "An OFFENSIVE ability activates -- the swing under an attack's impact, or a spell being loosed. A whoosh / release; support casts stay silent and let heal/buff speak." },
    ["battle.channel"] = { file = "assets/audio/battle/channel.ogg", category = "sfx", volume = 0.6,
        length = "<=0.7s", desc = "A powerful spell BEGINS winding up -- a channel/telegraph goes up (Meteor Storm and the like), on either side. A rising, building arcane charge; ominous, promising something big lands soon." },
    ["battle.step"] = { file = "assets/audio/battle/step.ogg", category = "sfx", volume = 0.4,
        length = "<=0.2s", desc = "One footstep, played once PER TILE a unit walks (either side). Must be tiny -- a whole route is a run of these." },

    -- Damage-type impacts -- the sound a surviving blow makes, chosen by its element/strike
    -- (ui/combat_fx.lua playHit, keyed on Motif.of(tags), the same reading the impact burst uses). A
    -- blow with none of these falls back to battle.hit / battle.crit. Physical three read as CONTACT;
    -- elementals read as the ELEMENT. A heavy typed blow rings its own cue pitched down.
    ["battle.hit_slash"] = { file = "assets/audio/battle/hit_slash.ogg", category = "sfx", volume = 0.8,
        length = "<=0.3s", desc = "Slash damage (swords, axes, claws, a bite). A clean edged CUT -- a swish into a shk." },
    ["battle.hit_pierce"] = { file = "assets/audio/battle/hit_pierce.ogg", category = "sfx", volume = 0.8,
        length = "<=0.3s", desc = "Pierce damage (spears, arrows, daggers, a stab). A sharp DRIVE / thock -- point going in." },
    ["battle.hit_impact"] = { file = "assets/audio/battle/hit_impact.ogg", category = "sfx", volume = 0.8,
        length = "<=0.35s", desc = "Impact damage (maces, hammers, fists, blunt). A heavy dull THUD -- no edge, all mass." },
    ["battle.hit_fire"] = { file = "assets/audio/battle/hit_fire.ogg", category = "sfx", volume = 0.7,
        length = "<=0.35s", desc = "Fire damage. A whooshing IGNITE / burst of flame -- filtered-noise roar with a soft attack." },
    ["battle.hit_ice"] = { file = "assets/audio/battle/hit_ice.ogg", category = "sfx", volume = 0.7,
        length = "<=0.35s", desc = "Ice damage. A crystalline FREEZE / shatter -- a high glassy ping with a brittle crack." },
    ["battle.hit_lightning"] = { file = "assets/audio/battle/hit_lightning.ogg", category = "sfx", volume = 0.7,
        length = "<=0.3s", desc = "Lightning damage. A sharp ZAP / crackle -- fast transient, electric snap, quick decay." },
    ["battle.hit_holy"] = { file = "assets/audio/battle/hit_holy.ogg", category = "sfx", volume = 0.7,
        length = "<=0.4s", desc = "Holy / radiant damage. A bright, ringing CHIME -- a clean consonant bell, warm and pure." },
    ["battle.hit_dark"] = { file = "assets/audio/battle/hit_dark.ogg", category = "sfx", volume = 0.7,
        length = "<=0.4s", desc = "Dark / shadow damage. A low, ominous WHUMP -- dull sub-heavy hit with a dissonant edge." },
    ["battle.hit_poison"] = { file = "assets/audio/battle/hit_poison.ogg", category = "sfx", volume = 0.7,
        length = "<=0.35s", desc = "Poison / nature damage. A wet BLURP / hiss -- bubbling, organic, faintly sickly." },
    ["battle.hit_water"] = { file = "assets/audio/battle/hit_water.ogg", category = "sfx", volume = 0.7,
        length = "<=0.35s", desc = "Water damage. A SPLASH / gush -- a burst of water, mid-bright, quick to settle." },
    ["battle.hit_acid"] = { file = "assets/audio/battle/hit_acid.ogg", category = "sfx", volume = 0.7,
        length = "<=0.35s", desc = "Acid damage. A corrosive SIZZLE -- high fizzing hiss, caustic, a little nasty." },

    -- Progress stings (states/game.lua, ui/panels/advancement.lua, models/conversation.lua).
    ["quest.complete"] = { file = "assets/audio/quest/complete.ogg", category = "sfx",
        length = "1-2s", desc = "An objective / quest clears. THE reward sting -- the moment the game most wants to celebrate." },
    ["quest.levelup"] = { file = "assets/audio/quest/levelup.ogg", category = "sfx",
        length = "1-1.5s", desc = "A companion levels up. A rising, celebratory chime." },
    ["quest.join"] = { file = "assets/audio/quest/join.ogg", category = "sfx",
        length = "1-1.5s", desc = "A companion joins the party (the join banner). A warm, welcoming flourish." },

    -- Music beds -- streamed, looping, one per place the player spends time (states/*). Seamless loops
    -- (author tail-to-head), 44.1kHz stereo. `music.credits` is the exception: it ENDS (loop = false).
    ["music.menu"] = { file = "assets/audio/music/menu.ogg", category = "music", volume = 0.8,
        length = "60-120s loop", desc = "Title screen. Calm, inviting, sits under a still screen -- the game's face." },
    ["music.hub"] = { file = "assets/audio/music/hub.ogg", category = "music", volume = 0.8,
        length = "90-150s loop", desc = "The town / hub city. Warm, unhurried, safe -- plays under long reading and shopping." },
    ["music.overworld"] = { file = "assets/audio/music/overworld.ogg", category = "music", volume = 0.8,
        length = "90-150s loop", desc = "The campaign map. Travelling, light forward motion, low tension." },
    ["music.battle"] = { file = "assets/audio/music/battle.ogg", category = "music",
        length = "60-120s loop", desc = "Ordinary battles. Tactical tension, steady pulse, never frantic." },
    ["music.boss"] = { file = "assets/audio/music/boss.ogg", category = "music",
        length = "60-120s loop", desc = "The seven generals / objective fights. The wall of the run -- heavier, thematic, a real antagonist." },
    ["music.credits"] = { file = "assets/audio/music/credits.ogg", category = "music", loop = false,
        length = "90-180s, ENDS", desc = "The ending roll. Resolution -- the one track with an authored close; plays once and stops." },
}
