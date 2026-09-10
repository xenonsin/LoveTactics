-- A DEBUG-BUILD RECORDING OF ONE FIGHT, written to a file as it happens.
--
-- The combat log already exists and is already the right data: Combat.logEvent is the single choke
-- point every damage line, status tick, trap trigger and phase announcement passes through, and it
-- stamps each entry with the turn it happened on. What it is not is DURABLE. `combat.log` is a rolling
-- 300-entry tail (Combat.LOG_CAP) held on a table that dies with the battle state, and the panel that
-- shows it holds a few dozen lines on screen at a time. So the one thing a tuning pass actually wants
-- -- the whole exchange, start to finish, readable after the window is closed -- is exactly what the
-- log cannot give.
--
-- This mirrors every entry to a file, and brackets it with the two things a bare stream of prose is
-- useless without:
--
--   * a HEADER naming both rosters as they stood at the bell -- pools, the flat stats, innate resists
--     and each body's grid. Reading "the Champion took 21" means nothing without the 8 defense and the
--     holy -8 that produced the 21, and those live in three different blueprints.
--   * a FOOTER with the result, the turn count, and every body's remaining health. "Won on turn 6 with
--     both party members above half" and "won on turn 14 with one body standing" are the same word in
--     the summary panel and completely different fights.
--
-- Gated on models/debug.lua's build constant, and OPENED BY THE BATTLE STATE rather than by Combat.new.
-- That seam is deliberate: the headless suite builds combats by the thousand and never goes through
-- states/battle.lua, so `& lovec . test` writes no files no matter what this module does. The rule in
-- models/debug.lua holds -- nothing here is the only way anything works, and a release build
-- (Debug.enabled = false) never so much as opens the directory.
--
-- Writes land immediately rather than being buffered to the close. A trace is most wanted for the fight
-- that ended in a crash or a hang, and a buffer is precisely what a crash throws away.
local Debug = require("models.debug")
local Combat = require("models.combat")

local Trace = {}

Trace.DIR = "combat-log"
Trace.KEEP = 20 -- traces kept on disk; the oldest beyond this are pruned as a new one opens

-- The open trace, or nil. One at a time: there is one battle on screen.
local live = nil

-- How many traces this session has opened, which is the tail of every filename.
--
-- The timestamp alone is not enough, and the case that proves it is the one the feature is most for: a
-- fight lost and retried at once. "Try Again" restarts the same fight with the same name inside the
-- same second, so a second-resolution stamp names the same file -- and open() truncates, so the losing
-- attempt would be erased by the attempt that replaced it. Zero-padded so a plain sort stays
-- oldest-first for prune().
local opened = 0

-- ---------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------

local function put(text)
    if not live then return end
    love.filesystem.append(live.path, (text or "") .. "\n")
end

-- A blueprint id or a body name reduced to something a filename can hold.
local function slug(s)
    return (tostring(s or "battle"):lower():gsub("[^%w]+", "-"):gsub("^%-+", ""):gsub("%-+$", ""))
end

-- ---------------------------------------------------------------------------
-- The roster header
-- ---------------------------------------------------------------------------

-- "62/62" for a pool, the bare number for a flat stat, "-" for a stat this body does not declare.
local function statText(v)
    if type(v) == "table" then return string.format("%d/%d", v.current or 0, v.max or 0) end
    if type(v) == "number" then return tostring(v) end
    return "-"
end

-- The innate mitigation a body wears instead of armour (models/character.lua `resist`), in the order
-- the blueprint happened to declare it -- sorted, so two traces of the same body read the same.
local function resistText(char)
    local r = char.resist
    if type(r) ~= "table" then return nil end
    local keys = {}
    for k in pairs(r) do keys[#keys + 1] = k end
    if #keys == 0 then return nil end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = string.format("%s %d", k, r[k]) end
    return table.concat(parts, ", ")
end

-- Every item id in the body's 3x3, in cell order, empties skipped. The grid is where half of what a
-- body can do lives -- an aura pays what it touches, a gate leaves its neighbour dead -- so a trace
-- that named only the stats would be missing the other half of the fight.
local function gridText(char)
    local out = {}
    for i = 1, 9 do
        local item = char.inventory and char.inventory[i]
        if type(item) == "table" then out[#out + 1] = item.id or item.name or "?" end
    end
    if #out == 0 then return nil end
    return table.concat(out, ", ")
end

local function writeUnit(u)
    local char = u.char
    if not char then return end
    local s = char.stats or {}
    put(string.format("  %-18s hp %-9s mana %-7s stam %-7s  atk %s/%s  def %s/%s  spd %s  mv %s",
        char.name or "?", statText(s.health), statText(s.mana), statText(s.stamina),
        statText(s.damage), statText(s.magicDamage), statText(s.defense), statText(s.magicDefense),
        statText(s.speed), statText(s.movement)))
    local resist = resistText(char)
    if resist then put("      resist: " .. resist) end
    local grid = gridText(char)
    if grid then put("      grid:   " .. grid) end
end

-- The bodies on one side. A combat keeps ONE list (combat.units) with `side` on each body rather than
-- two rosters, so both the header and the footer filter here -- which also means a Bomblet called
-- mid-fight shows up in the footer under the side that called it, standing or dead.
local function side(combat, want)
    local out = {}
    for _, u in ipairs((combat and combat.units) or {}) do
        if u.side == want then out[#out + 1] = u end
    end
    return out
end

local function writeRoster(label, units)
    put("")
    put("-- " .. label .. " --")
    for _, u in ipairs(units or {}) do writeUnit(u) end
end

-- ---------------------------------------------------------------------------
-- Pruning
-- ---------------------------------------------------------------------------

-- Drop all but the newest KEEP traces. Names are timestamp-first, so a plain sort is newest-last and
-- no file has to be stat'ed to know its age.
local function prune()
    local names = love.filesystem.getDirectoryItems(Trace.DIR)
    if #names <= Trace.KEEP then return end
    table.sort(names)
    for i = 1, #names - Trace.KEEP do
        love.filesystem.remove(Trace.DIR .. "/" .. names[i])
    end
end

-- ---------------------------------------------------------------------------
-- Open / record / close
-- ---------------------------------------------------------------------------

-- "assassinate -> character_demon_champion", or nil for a fight with no named end. Here rather than at
-- the call site because states/battle.lua is a couple of declarations from Lua 5.1's 200-local ceiling
-- and cannot spare a local to unpack this into.
function Trace.describeObjective(obj)
    if type(obj) ~= "table" or not obj.type then return nil end
    if obj.target then return obj.type .. " -> " .. tostring(obj.target) end
    return obj.type
end

-- Begin a trace for `combat`. `meta` is whatever the caller knows about the fight and none of it is
-- required: { name, kind, objective, layout, biome, day, prestige, enemyLevel }.
--
-- Returns the trace's save-directory-relative path, or nil in a release build. Safe to call twice: a
-- second open closes the first as abandoned, so a retried fight starts a clean file rather than
-- appending a second battle onto the tail of the one it is replacing.
function Trace.open(combat, meta)
    if not Debug.enabled or not combat then return nil end
    if not love.filesystem then return nil end
    if live then Trace.close("abandoned") end
    meta = meta or {}

    love.filesystem.createDirectory(Trace.DIR)
    opened = opened + 1
    live = {
        combat = combat,
        path = string.format("%s/%s-%03d_%s.log", Trace.DIR, os.date("%Y%m%d-%H%M%S"),
            opened % 1000, slug(meta.name)),
        openedAt = os.time(),
        turn = nil,
        lines = 0,
    }
    love.filesystem.write(live.path, "") -- truncate, so a same-second retry never doubles up

    put("=== Project Tactics combat trace ===")
    put("opened     " .. os.date("%Y-%m-%d %H:%M:%S"))
    put("encounter  " .. tostring(meta.name or "Battle") .. "  (" .. tostring(meta.kind or "combat") .. ")")
    if meta.objective then put("objective  " .. meta.objective) end
    put(string.format("board      %s, biome %s", tostring(meta.layout or "rolled"), tostring(meta.biome or "-")))
    put(string.format("day %s   prestige %s   enemy level %s",
        tostring(meta.day or "-"), tostring(meta.prestige or "-"), tostring(meta.enemyLevel or "-")))
    writeRoster("party", side(combat, "party"))
    writeRoster("enemies", side(combat, "enemy"))

    -- From here every logEvent is mirrored. The hook is a plain field on the Combat module rather than
    -- a require of this file from there: combat.lua stays ignorant of the filesystem, and a build with
    -- no trace open pays one nil test per logged line.
    Combat.trace = Trace.record

    -- ...and anything the fight already said before the hook was live. Combat.new opens the battle
    -- itself unless a deployment phase is coming, so the bell and every battle-opener trait have
    -- already logged by the time the caller gets a combat back to trace. Without this the first lines
    -- of every fight are the ones missing from the file.
    for _, entry in ipairs(combat.log or {}) do Trace.record(combat, entry) end

    prune()
    return live.path
end

-- One combat-log entry, exactly as Combat.logEvent appended it. Turn changes announce themselves, so
-- the file reads as rounds rather than as one 300-line paragraph.
function Trace.record(combat, entry)
    if not live or live.combat ~= combat or not entry then return end
    local turn = entry.turn or 0
    if turn ~= live.turn then
        live.turn = turn
        put("")
        put("--- turn " .. tostring(turn) .. " ---")
    end
    live.lines = live.lines + 1
    put(string.format("  %-9s %s", entry.kind or "system", entry.text or ""))
end

-- What every body had left. The half of "did the party win" that the word "win" does not carry.
local function writeStanding(label, units)
    local parts = {}
    for _, u in ipairs(units or {}) do
        local hp = u.char and u.char.stats and u.char.stats.health
        local cur, max = 0, 0
        if type(hp) == "table" then cur, max = hp.current or 0, hp.max or 0 end
        parts[#parts + 1] = string.format("%s %d/%d%s", (u.char and u.char.name) or "?", cur, max,
            u.alive and "" or " (dead)")
    end
    if #parts > 0 then put(string.format("  %-8s %s", label, table.concat(parts, ", "))) end
end

-- Close the open trace. `result` is whatever the caller calls the ending -- "win", "loss", "forfeit",
-- "abandoned" -- and is written as given. Harmless when nothing is open, so the battle state can call
-- it on every exit path without asking whether this build traces.
function Trace.close(result)
    if not live then return nil end
    local combat, path = live.combat, live.path
    put("")
    put(string.format("=== result: %s on turn %d, %d lines, %ds elapsed ===",
        tostring(result or "ended"), combat and combat.turnCount or 0, live.lines,
        os.time() - live.openedAt))
    if combat then
        writeStanding("party", side(combat, "party"))
        writeStanding("enemies", side(combat, "enemy"))
    end
    live = nil
    Combat.trace = nil
    return path
end

-- The absolute path of the open trace, for printing to the console -- the save directory is off in the
-- user's AppData and nobody guesses their way to it.
function Trace.absolutePath()
    if not live then return nil end
    return love.filesystem.getSaveDirectory() .. "/" .. live.path
end

return Trace
