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
--   Sound.update(dt)                    -- per frame from main.lua; revives a bed that fell silent
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

-- Resolve a bed to the first cue in its `fallback` chain whose file is actually on disk.
--
-- A BED THAT HAS NOT BEEN WRITTEN DOES NOT MERELY FAIL TO PLAY -- it takes the one that was playing
-- with it, because Sound.music stops the running track before it discovers the new one cannot load.
-- That is not the art debt showing through, it is the art debt reaching backwards: every objective
-- fight in the game asks for `music.boss`, which is uncommissioned, so the fight fell silent the
-- instant it began and stayed silent through the win. So an unwritten bed asks for the nearest one
-- that exists instead (data/sounds.lua names the chain), and the fallback disappears on its own the
-- day the file lands. `seen` guards a chain authored into a cycle.
--
-- Resolved by asking the filesystem rather than by loading and catching the failure -- the same
-- reason models/sprite.lua asks: under love.js a failed load does not raise, it stops the main loop.
local function resolveMusic(id)
    local seen = {}
    while id and not seen[id] do
        seen[id] = true
        local def = Sound.cues[id]
        if not def or not def.file then return nil end
        local canAsk = love and love.filesystem and love.filesystem.getInfo
        if not canAsk or love.filesystem.getInfo(def.file) then return id, def end
        id = def.fallback
    end
    return nil
end

-- Start (or keep) the looping bed named by `id`. Asking for the track already playing is a no-op, so
-- a state that sets its own music on every `enter` does not restart the bed each time it is entered
-- -- and that is asked of the RESOLVED id, so a state re-entering a fight whose boss bed falls back
-- to the ordinary one does not restart the ordinary one either.
-- `nil` stops the music, so `Sound.music(biome.music)` works with no branch at the call site.
function Sound.music(id)
    if id == nil then return Sound.stopMusic() end

    local resolved, def = resolveMusic(id)
    if not resolved then Sound.stopMusic(); return nil end
    if current and current.id == resolved then return current.source end

    Sound.stopMusic()

    local source = Sound.load(def.file, "stream")
    if not isSource(source) then return nil end

    pcall(function()
        source:setLooping(def.loop ~= false)
        source:setVolume(Sound.volumeOf("music") * (def.volume or 1))
        source:play()
    end)
    current = { id = resolved, source = source, at = 0, still = 0, moved = false }
    return source
end

-- ---------------------------------------------------------------------------
-- The bed that dies while the player is away
-- ---------------------------------------------------------------------------
--
-- THE WEB BUILD'S MUSIC, kept alive across an alt-tab.
--
-- A music bed is a STREAM: the engine holds a few tenths of a second of decoded audio and refills the
-- queue every frame. On the desktop that refill runs on LOVE's own audio thread and never stops. Under
-- love.js there is no audio thread -- the compatibility build is the engine with the threads taken out
-- (tools/web-build.ps1) -- so the refill rides the main loop, and the main loop is
-- `requestAnimationFrame`, which the browser stops calling the moment the tab goes to the background.
-- A few frames later the queue is empty and OpenAL parks the source.
--
-- Coming back does not undo it. The engine still believes a LOOPING stream is playing (a loop is never
-- "finished", so nothing releases it and `isPlaying` keeps saying yes) while the source underneath has
-- stopped, and the bed is gone for the rest of the session -- exactly what alt-tabbing away from the
-- web build did.
--
-- So the bed is watched by its POSITION rather than by `isPlaying`, which is the thing that lies. A
-- track whose clock has not moved for half a second of frames is dead however it died, and is stopped,
-- seeked back to where it fell silent, and started again -- a stop is required first, since the engine
-- thinks it is already playing and would ignore a bare `play`.
--
-- Three properties keep this from being a hazard of its own:
--
--   * it self-gates on FRAMES. A hidden tab runs none, so the check cannot fire while the player is
--     away -- the bed comes back when they do, rather than playing to an empty room.
--   * the frame budget is CLAMPED (`STALL_STEP`), so the one enormous dt that arrives on return does
--     not trip it instantly. The engine gets ~15 frames to recover on its own, and if it does -- the
--     position moves -- nothing here touches it.
--   * it demands EVIDENCE that the clock works at all (`moved`). Where `tell` is unimplemented and
--     answers a constant, this degrades to today's behaviour -- silence -- rather than to a bed that
--     restarts itself every half second forever.
--
-- Desktop is unaffected in practice: its bed never stops, so the position always moves.

Sound.STALL_SECONDS = 0.5 -- how long a bed's clock may stand still before it counts as dead
Sound.STALL_STEP = 1 / 30 -- the most any single frame may contribute to that (see above)

-- Fold one position reading into a bed's stall bookkeeping; true when it has been still long enough to
-- count as dead. `track` is the mutable table Sound.music built ({ at, still, moved }).
--
-- Exported rather than local because it is the half of the watchdog a headless test can actually
-- exercise: producing a REAL stall needs a browser tab going away. See tests/sound_spec.lua.
function Sound.stall(track, at, dt)
    if at ~= track.at then
        track.at, track.still, track.moved = at, 0, true
        return false
    end
    track.still = (track.still or 0) + math.min(dt or 0, Sound.STALL_STEP)
    return track.moved == true and track.still >= Sound.STALL_SECONDS
end

-- Per frame, from main.lua. Cheap: one position read while all is well.
function Sound.update(dt)
    if not current or not isSource(current.source) then return end

    -- A bed authored to END (music.credits) is allowed to end; only a loop is expected to still be
    -- running, so only a loop may be revived.
    local def = Sound.cues[current.id]
    if def and def.loop == false then return end

    local ok, at = pcall(function() return current.source:tell("seconds") end)
    if not ok or type(at) ~= "number" then return end
    if not Sound.stall(current, at, dt) then return end

    current.still = 0
    pcall(function() current.source:stop() end)  -- the engine thinks it is playing; take that away
    pcall(function() current.source:seek(at, "seconds") end) -- and resume where the silence began
    pcall(function() current.source:play() end)
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
