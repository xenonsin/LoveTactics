-- Player preferences: per-INSTALL options, as opposed to per-run progress.
--
-- Deliberately separate from models/save.lua and its save.lua file. A preference is a fact about the
-- person at the keyboard, not about the campaign they are playing, so "New Game erases your save"
-- must never erase it -- and a preference has to be readable from the main menu, before any player
-- exists to hang it off. Two files, two lifetimes.
--
--   Settings.get("tooltip_keywords")        -- the current value, or the default
--   Settings.set("tooltip_keywords", true)  -- in memory only
--   Settings.save()                         -- ... and now on disk
--
-- `set` does not write. Persisting is the caller's call, which is what lets a test flip a preference
-- for one case without rewriting the player's real file. states/settings.lua saves on every change,
-- so for the player it is immediate all the same.
--
-- Values are SCALARS -- boolean, number, string -- and nothing else. That contract is what lets this
-- module carry its own eight-line writer instead of pulling in the save system's serializer, which
-- would drag models/character.lua and the whole item registry into the main menu's load path.
--
-- Headless-safe: love.filesystem only, no love.graphics at require time.

local Settings = {}

Settings.FILE = "settings.lua"

-- Every option the game has, in the order the settings screen lists them. Adding one here is the
-- whole job: states/settings.lua renders the list, and nothing else needs to learn the new key.
--
--   key         -- the id read/written through get/set, and the key in the settings file
--   name        -- the row's label
--   description -- the line under it, explaining what the option buys
--   default     -- the value a fresh install starts on
--   kind        -- "toggle" (a boolean) or "range" (a number, stepped between min and max)
--   min/max/step -- range only; the bounds and the increment one press moves
Settings.defs = {
    -- Volume first, because it is the option a player reaches for in the first thirty seconds and the
    -- only one here they may need in a hurry. Master scales the other two (models/sound.lua), so it
    -- sits above them and the pair below it keep their balance as it moves.
    --
    -- Defaults are 70 rather than 100: a fresh install should be quieter than the loudest the game can
    -- be, so the first adjustment a player makes has somewhere to go in both directions.
    {
        key = "volume_master",
        name = "Master volume",
        description = "Scales everything the game plays. The music and effects levels below are "
            .. "measured against it, so moving this keeps their balance.",
        default = 70,
        kind = "range",
        min = 0, max = 100, step = 10,
    },
    {
        key = "volume_music",
        name = "Music volume",
        description = "The looping bed under the menus, the town, the road and a fight.",
        default = 70,
        kind = "range",
        min = 0, max = 100, step = 10,
    },
    {
        key = "volume_sfx",
        name = "Effects volume",
        description = "Blows, spells, menu clicks, and the stings that mark a fight ending.",
        default = 80,
        kind = "range",
        min = 0, max = 100, step = 10,
    },
    {
        key = "tooltip_keywords",
        name = "Keywords in tooltips",
        -- Says what stays behind when it is off, because that is the part a player would otherwise
        -- have to test to find out: turning this off does not blind them to what a weapon inflicts.
        description = "Defines ability keywords -- Area, Dead Zone, Frenzy -- in the glossary beside "
            .. "item tooltips and in shop details. Status effects are defined either way.",
        default = false,
        kind = "toggle",
    },
    {
        key = "reduced_effects",
        name = "Reduced effects",
        -- Says what survives, because that is the fear this option has to answer: a player who turns
        -- it on must know they are not turning off the picture that tells them what hit them. Only
        -- the effects that move the WHOLE FRAME go -- the shake, the freeze, the punch on a killing
        -- blow. Every burst, dissolve and tile field stays exactly as it was.
        description = "Stops the screen shaking, freezing or lurching on a heavy blow. Impacts, "
            .. "spell effects and hazard grounds are unaffected.",
        default = false,
        kind = "toggle",
    },
    {
        key = "enemy_intent",
        -- ON by default: perfect information is the whole design, and Into the Breach's evidence is that
        -- it makes players play MORE tactically, not less. But it is the one read that changes the felt
        -- difficulty of a fight -- some players want the fog back -- so it earns a switch of its own.
        name = "Show enemy intent",
        description = "Reveals who each enemy will strike and what it will do -- a target line on the "
            .. "board and an icon on the turn order. Turn it off to fight without knowing.",
        default = true,
        kind = "toggle",
    },
    {
        key = "danger_vignette",
        name = "Low-health screen edge",
        -- OFF by default, unlike every other option here: a red wash creeping in from the edges of
        -- the board is the one effect that competes with the board itself for the eye, and the HP
        -- bars already say the same thing exactly. A player who wants the pressure can ask for it.
        description = "Darkens the edges of the screen in red as your most wounded fighter nears "
            .. "death. Off by default -- the health bars carry the same warning.",
        default = false,
        kind = "toggle",
    },
}

local byKey = {}
for _, def in ipairs(Settings.defs) do byKey[def.key] = def end

-- Loaded values, nil until the first get/set pulls the file in. A key absent from this table falls
-- through to its default, so a settings file written before an option existed still loads.
local values

-- Encode a scalar as a Lua literal. Anything else is an authoring error rather than a runtime case:
-- the defs above are the only source of keys, and every one of them is a scalar by contract.
local function encode(value)
    local t = type(value)
    if t == "boolean" or t == "number" then return tostring(value) end
    if t == "string" then return string.format("%q", value) end
    error("settings: cannot serialize a " .. t)
end

-- Run the settings file and hand back the table it returns, or nil. Sandboxed exactly as a save file
-- is (models/save.lua): this is executable Lua sitting in a directory the player can open, so it gets
-- no access to globals even when hand-edited.
local function decode(source)
    local loader = loadstring or load
    local chunk = loader(source, "settings")
    if not chunk then return nil end
    if setfenv then setfenv(chunk, {}) end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then return nil end
    return result
end

-- Read the file, keeping only keys that are still real options carrying a value of the expected
-- type. A hand-edited or stale file therefore degrades to defaults rather than poisoning the game
-- with a string where a boolean belongs.
local function loadFile()
    values = {}
    if not (love.filesystem and love.filesystem.getInfo(Settings.FILE)) then return end
    local source = love.filesystem.read(Settings.FILE)
    local result = source and decode(source)
    if not result then return end
    for key, value in pairs(result) do
        local def = byKey[key]
        if def and type(value) == type(def.default) then values[key] = value end
    end
end

-- The value of `key`: what was loaded or set, else the option's default. An unknown key is nil,
-- which reads as "off" at every call site that gates on one.
function Settings.get(key)
    if not values then loadFile() end
    local stored = values[key]
    if stored ~= nil then return stored end
    local def = byKey[key]
    return def and def.default
end

-- Set `key` in memory. Returns the new value, so a toggle can act and report in one line.
function Settings.set(key, value)
    if not values then loadFile() end
    values[key] = value
    return value
end

-- Flip a boolean option. `get` already folds in the default, so the first flip on a fresh install
-- turns the DEFAULT over rather than turning a nil into true.
function Settings.toggle(key)
    return Settings.set(key, not Settings.get(key))
end

-- Move a "range" option one step in `dir` (-1 or 1), clamped to its bounds. Returns the new value.
--
-- Clamped rather than wrapping, deliberately: a volume that jumps from silent to full because the
-- player pressed left once too often is a genuinely unpleasant surprise, and the one option where
-- overshooting is loud is the one where wrapping is worst.
function Settings.step(key, dir)
    local def = byKey[key]
    if not def or def.kind ~= "range" then return Settings.get(key) end

    local value = (Settings.get(key) or def.default) + (def.step or 1) * (dir or 1)
    if value < def.min then value = def.min end
    if value > def.max then value = def.max end
    return Settings.set(key, value)
end

-- Write the current values out. Every option is written, defaults included, so the file is a full
-- statement of the player's preferences and not a diff against whatever the defaults happen to be
-- in the build that wrote it.
function Settings.save()
    if not values then loadFile() end
    local parts = { "return {" }
    for _, def in ipairs(Settings.defs) do
        parts[#parts + 1] = string.format("    [%q] = %s,", def.key, encode(Settings.get(def.key)))
    end
    parts[#parts + 1] = "}"
    return love.filesystem.write(Settings.FILE, table.concat(parts, "\n") .. "\n")
end

-- Drop everything loaded, so the next read comes off disk again. For tests, which flip preferences in
-- memory and must not leak them into the case that runs next.
function Settings.reload()
    values = nil
end

return Settings
