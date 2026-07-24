-- The cue table: every sound the game can ask for, declared as data.
--
-- This file is the audio equivalent of a blueprint's `sprite` field, and it exists for the same
-- reason art paths live in data rather than in the drawing code: the roster of sounds the game wants
-- has to be READABLE and COUNTABLE without running it. `. audio-report` walks this table against what
-- is on disk and prints the debt, exactly as `. art-report` does for images.
--
-- Nothing here has a file yet. That is the point, and it is safe: models/sound.lua resolves a missing
-- file to silence, so every cue below is already wired at its call site, already does nothing, and
-- starts making noise the moment an .ogg lands at the path it names. Audio can therefore arrive one
-- file at a time instead of in one commit, which is how the 502 item icons got made.
--
-- A cue is `{ file, category, volume, loop }`:
--   file     -- where the audio will live. Named now so the report can count it and an author has a
--               target path rather than a naming argument.
--   category -- "sfx" or "music"; picks which volume preference scales it (models/sound.lua).
--   volume   -- optional per-cue trim, 0..1, for a cue that is simply too loud against the rest.
--               Mixing lives here rather than in the file, so balance is a one-line diff.
--   loop     -- music only; defaults to true for a bed, set false for a one-shot sting.
--
-- Ogg Vorbis throughout: it is what LÖVE decodes everywhere without a licence question, and the
-- streaming path for music wants a format that seeks cheaply.
--
-- Naming is `<area>.<thing>`, and the areas are deliberately coarse. A cue per item would be a
-- thousand rows nobody fills; a cue per KIND of event is a roster an audio pass can actually finish.
return {
    -- UI -- the shared widgets, so wiring these once covers every menu in the game (ui/menu.lua).
    ["ui.move"]    = { file = "assets/audio/ui/move.ogg",    category = "sfx", volume = 0.5 },
    ["ui.confirm"] = { file = "assets/audio/ui/confirm.ogg", category = "sfx" },
    ["ui.cancel"]  = { file = "assets/audio/ui/cancel.ogg",  category = "sfx", volume = 0.8 },
    ["ui.denied"]  = { file = "assets/audio/ui/denied.ogg",  category = "sfx", volume = 0.7 },

    -- Battle flow. Coarse on purpose: one hit, one death, one heal, whatever the weapon was. A
    -- per-weapon layer can be added later by giving items their own `sound` field; the flow cues
    -- below are the floor that makes the game stop being silent.
    ["battle.start"]  = { file = "assets/audio/battle/start.ogg",  category = "sfx" },
    ["battle.win"]    = { file = "assets/audio/battle/win.ogg",    category = "sfx" },
    ["battle.loss"]   = { file = "assets/audio/battle/loss.ogg",   category = "sfx" },
    ["battle.hit"]    = { file = "assets/audio/battle/hit.ogg",    category = "sfx", volume = 0.8 },
    ["battle.crit"]   = { file = "assets/audio/battle/crit.ogg",   category = "sfx" },
    ["battle.miss"]   = { file = "assets/audio/battle/miss.ogg",   category = "sfx", volume = 0.6 },
    ["battle.death"]  = { file = "assets/audio/battle/death.ogg",  category = "sfx" },
    ["battle.heal"]   = { file = "assets/audio/battle/heal.ogg",   category = "sfx", volume = 0.7 },
    ["battle.status"] = { file = "assets/audio/battle/status.ogg", category = "sfx", volume = 0.6 },
    ["battle.turn"]   = { file = "assets/audio/battle/turn.ogg",   category = "sfx", volume = 0.5 },

    -- Progress. The quest sting is the one piece of audio the game most obviously lacks -- a fight
    -- ends and nothing marks it.
    ["quest.complete"] = { file = "assets/audio/quest/complete.ogg", category = "sfx" },
    ["quest.levelup"]  = { file = "assets/audio/quest/levelup.ogg",  category = "sfx" },
    ["quest.join"]     = { file = "assets/audio/quest/join.ogg",     category = "sfx" },

    -- Music beds, one per place the player spends time. `biome` names line up with data/biomes/ so a
    -- board can ask for its own bed by id without a lookup table in between.
    ["music.menu"]       = { file = "assets/audio/music/menu.ogg",       category = "music", volume = 0.8 },
    ["music.hub"]        = { file = "assets/audio/music/hub.ogg",        category = "music", volume = 0.8 },
    ["music.overworld"]  = { file = "assets/audio/music/overworld.ogg",  category = "music", volume = 0.8 },
    ["music.battle"]     = { file = "assets/audio/music/battle.ogg",     category = "music" },
    ["music.boss"]       = { file = "assets/audio/music/boss.ogg",       category = "music" },
    -- The credits bed is the one track with an authored end: it plays once and stops rather than
    -- looping under a roll that has already finished (states/credits.lua).
    ["music.credits"]    = { file = "assets/audio/music/credits.ogg",    category = "music", loop = false },
}
