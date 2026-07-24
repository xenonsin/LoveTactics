-- Memoized sound loader and playback -- the audio twin of models/sprite.lua, and deliberately built
-- to the same tolerance rule: **a missing file is never an error.**
--
-- That rule is the whole reason this module exists before any audio does. Sprite.load resolves a
-- missing image to its own path string rather than crashing, which is what let 502 item icons land
-- one at a time over months without the game ever being broken in between. Audio needs exactly the
-- same property or it can only arrive in one big commit: every cue below can be called today, does
-- nothing at all, and starts making noise the moment a file appears at the path its cue names.
--
-- So `Sound.play` returns nil and shrugs when the file is absent, when love.audio is missing, or when
-- there is no audio device. No caller ever branches on whether the sound exists.
--
--   Sound.play("ui.confirm")            -- a one-shot cue from data/sounds.lua
--   Sound.music("music.hub")            -- the looping bed; swapping tracks is idempotent
--   Sound.stopMusic()
--   Sound.refresh()                     -- re-read the volume preferences and push them to live audio
--
-- Volumes are three preferences (models/settings.lua): master, music and sfx, each 0-100. A category's
-- effective gain is master x category, so pulling master down pulls everything with it and the two
-- sliders under it keep their relative balance.
--
-- Headless-safe: no love.graphics anywhere, and every love.audio call is guarded. The test suite runs
-- with `t.window = false` but still HAS love.audio, so the guards are load-bearing rather than
-- decorative -- see tests/sound_spec.lua.

local Settings = require("models.settings")

local Sound = {}

-- The cue table (data/sounds.lua): id -> { file, category, volume, loop }. Loaded through pcall so a
-- build without the data file still runs -- the same forgiveness every other layer here shows.
local okCues, cues = pcall(require, "data.sounds")
Sound.cues = okCues and cues or {}

-- Loaded Sources by path. A cached entry may be the path STRING rather than a Source: that is the
-- "could not load" marker, and it is cached deliberately so a missing file is not retried on every
-- single play. Mirrors the cache in models/sprite.lua, including that subtlety.
local cache = {}

-- The currently playing music: { id, source }. One bed at a time by construction -- two overlapping
-- loops is never a thing anyone wants, and making it impossible is cheaper than managing it.
local current = nil

-- ---------------------------------------------------------------------------
-- Volume
-- ---------------------------------------------------------------------------

Sound.MAX_VOLUME = 100

-- A category's effective gain, 0..1: the master preference multiplied by the category's own. An
-- unknown category falls back to master alone rather than to silence, so a cue authored with a typo
-- is audible and therefore findable.
function Sound.volumeOf(category)
    local master = (Settings.get("volume_master") or Sound.MAX_VOLUME) / Sound.MAX_VOLUME
    local own = Sound.MAX_VOLUME
    if category == "music" then
        own = Settings.get("volume_music") or Sound.MAX_VOLUME
    elseif category == "sfx" then
        own = Settings.get("volume_sfx") or Sound.MAX_VOLUME
    end
    return master * (own / Sound.MAX_VOLUME)
end

-- Push the current preferences onto anything already playing. Called by the settings screen on every
-- change, so dragging the music slider is audible while the bed is playing rather than at the next
-- track change -- which is the only way a player can actually set a level.
function Sound.refresh()
    if current and current.source and current.source.setVolume then
        local def = Sound.cues[current.id]
        local scale = (def and def.volume) or 1
        pcall(function() current.source:setVolume(Sound.volumeOf("music") * scale) end)
    end
end

-- ---------------------------------------------------------------------------
-- Loading
-- ---------------------------------------------------------------------------

local function audioAvailable()
    return love and love.audio and love.audio.newSource
end

-- A Source for `path`, or the path string when one cannot be made. `kind` is "static" (decoded into
-- memory -- right for short effects) or "stream" (decoded as it plays -- right for music beds).
function Sound.load(path, kind)
    if path == nil then return nil end
    if cache[path] ~= nil then return cache[path] end

    local source = path -- fallback: keep the path if it can't be loaded
    if audioAvailable() and love.filesystem and love.filesystem.getInfo(path) then
        local ok, result = pcall(love.audio.newSource, path, kind or "static")
        if ok then source = result end
    end

    cache[path] = source
    return source
end

-- True when `value` came back from load as a real Source rather than the path-string fallback.
local function isSource(value)
    return type(value) == "userdata" and value.play ~= nil
end

-- ---------------------------------------------------------------------------
-- Playback
-- ---------------------------------------------------------------------------

-- Fire a one-shot cue by id. Returns the playing Source, or nil when there was nothing to play --
-- which is the ordinary case until the audio actually exists, and is never worth logging.
--
-- The source is CLONED per play so two of the same cue can overlap (two blows landing in the same
-- frame). Cloning a static source is cheap; the cached original is never played and stays the
-- template.
function Sound.play(id, opts)
    local def = Sound.cues[id]
    if not def or not def.file then return nil end

    local template = Sound.load(def.file, "static")
    if not isSource(template) then return nil end

    local ok, source = pcall(function() return template:clone() end)
    if not ok or not isSource(source) then return nil end

    local scale = (opts and opts.volume) or def.volume or 1
    pcall(function()
        source:setVolume(Sound.volumeOf(def.category or "sfx") * scale)
        if opts and opts.pitch then source:setPitch(opts.pitch) end
        source:play()
    end)
    return source
end

-- Start (or keep) the looping bed named by `id`. Asking for the track already playing is a no-op, so
-- a state that sets its own music on every `enter` does not restart the bed each time it is entered.
-- `nil` stops the music, so `Sound.music(biome.music)` works with no branch at the call site.
function Sound.music(id)
    if id == nil then return Sound.stopMusic() end
    if current and current.id == id then return current.source end

    Sound.stopMusic()

    local def = Sound.cues[id]
    if not def or not def.file then return nil end

    local source = Sound.load(def.file, "stream")
    if not isSource(source) then return nil end

    pcall(function()
        source:setLooping(def.loop ~= false)
        source:setVolume(Sound.volumeOf("music") * (def.volume or 1))
        source:play()
    end)
    current = { id = id, source = source }
    return source
end

function Sound.stopMusic()
    if current and isSource(current.source) then
        pcall(function() current.source:stop() end)
    end
    current = nil
end

-- The id of the bed currently playing, or nil. Exposed for tests and for a state that wants to know
-- whether it is already on the right track.
function Sound.currentMusic()
    return current and current.id or nil
end

-- Drop every cached Source. For tests, which must not carry a loaded (or failed) path between cases.
function Sound.reset()
    Sound.stopMusic()
    for k in pairs(cache) do cache[k] = nil end
end

return Sound
