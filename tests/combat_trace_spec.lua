-- Tests for the debug-build combat trace (models/combat_trace.lua): the file a fight writes as it is
-- fought, so a tuning pass has something to read after the window is closed.
--
-- The claim worth pinning hardest is DURABILITY, because it is the entire reason the feature exists.
-- `combat.log` is a rolling 300-entry tail (Combat.LOG_CAP) and a long fight silently drops its own
-- opening off the front of it. A trace that inherited that ceiling would be an elaborate way of keeping
-- exactly what the game already keeps, so "the 400th line is in the file AND the 1st line is still in
-- the file" is the assertion this module lives or dies on.
--
-- Second: the GATE. Everything here is debug-build only (models/debug.lua), and the seam that keeps the
-- headless suite from writing files is that only states/battle.lua opens a trace -- never Combat.new.
-- So the suite builds combats by the thousand and writes nothing, which is a property this spec has to
-- demonstrate rather than assume, since it is the one thing that would make `. test` start littering
-- someone's save directory.
--
-- These cases WRITE FILES, which no other spec does. Two precautions, both mandatory:
--   * Trace.DIR is redirected to a test folder for the duration, so pruning can never reach a real
--     trace the developer is in the middle of reading.
--   * every case closes what it opened, in case the module-level `Combat.trace` hook were left armed
--     and pointed at a file that is about to be deleted.

local Trace = require("models.combat_trace")
local Combat = require("models.combat")
local Debug = require("models.debug")

local TEST_DIR = "combat-log-spec"

-- A combat thin enough to trace but real enough to be traced: the trace only ever reads `units`
-- (with `side`, `char`, `alive`), `objective`, `log` and `turnCount`, and never calls into the model.
local function fakeCombat()
    local function body(name, side, hp)
        return { side = side, alive = true,
            char = { name = name, stats = { health = { current = hp, max = hp }, damage = 10 } } }
    end
    return {
        units = { body("Stranger", "party", 62), body("Demon Champion", "enemy", 150) },
        objective = { type = "assassinate", target = "character_demon_champion" },
        log = {},
        turnCount = 0,
    }
end

-- Everything written under the test directory, so a case can read back what it wrote and the whole
-- folder can be swept afterward.
local function readTrace(path)
    return love.filesystem.read(path) or ""
end

local function sweep()
    for _, name in ipairs(love.filesystem.getDirectoryItems(TEST_DIR)) do
        love.filesystem.remove(TEST_DIR .. "/" .. name)
    end
    love.filesystem.remove(TEST_DIR)
end

-- Run `fn` with the trace pointed at the test folder, then close, sweep and restore -- whatever
-- happened. A failed assertion inside `fn` must not leave the Combat.trace hook armed for the 2800
-- specs that run after this one.
local function sandboxed(fn)
    local realDir, realKeep = Trace.DIR, Trace.KEEP
    Trace.DIR = TEST_DIR
    local ok, err = pcall(fn)
    Trace.close("spec")
    sweep()
    Trace.DIR, Trace.KEEP = realDir, realKeep
    if not ok then error(err, 0) end
end

return {
    {
        name = "the header names both sides, the objective and each body's grid stats",
        fn = function()
            sandboxed(function()
                local combat = fakeCombat()
                local path = Trace.open(combat, { name = "The Demon Champion", kind = "objective",
                    objective = Trace.describeObjective(combat.objective), biome = "castle", day = 1 })
                assert(path, "a debug build opens a trace")
                local text = readTrace(path)
                assert(text:find("The Demon Champion", 1, true), "the encounter is named")
                assert(text:find("assassinate %-> character_demon_champion"), "so is what wins it")
                assert(text:find("%-%- party %-%-") and text:find("%-%- enemies %-%-"), "both rosters")
                assert(text:find("Stranger") and text:find("Demon Champion"), "and both bodies")
                assert(text:find("150/150", 1, true), "with the pool the fight is priced against")
            end)
        end,
    },
    {
        name = "the objective description survives a fight that has no named end",
        fn = function()
            assert(Trace.describeObjective({ type = "killAll" }) == "killAll", "a bare type stands alone")
            assert(Trace.describeObjective(nil) == nil, "and nothing is not a description")
            assert(Trace.describeObjective({}) == nil, "neither is a table with no type")
        end,
    },
    {
        name = "a line logged before the trace opened is still in the file",
        fn = function()
            sandboxed(function()
                local combat = fakeCombat()
                -- Combat.new opens the battle itself unless a deployment phase is coming, so the bell
                -- has already rung by the time states/battle.lua has a combat to trace. Without the
                -- backfill the first lines of every fight are the ones missing.
                Combat.logEvent(combat, "system", "The battle begins.")
                local path = Trace.open(combat, { name = "backfill" })
                assert(readTrace(path):find("The battle begins.", 1, true),
                    "the opening line is recovered from combat.log, not lost to it")
            end)
        end,
    },
    {
        name = "the file outlives the log's 300-entry ceiling, which is the whole point",
        fn = function()
            sandboxed(function()
                local combat = fakeCombat()
                local path = Trace.open(combat, { name = "long fight" })
                for i = 1, Combat.LOG_CAP + 100 do
                    Combat.logEvent(combat, "damage", "blow number " .. i)
                end
                assert(#combat.log == Combat.LOG_CAP, "the in-memory log is still a rolling tail")
                assert(combat.log[1].text ~= "blow number 1", "and it has already dropped its opening")
                local text = readTrace(path)
                assert(text:find("blow number 1\n", 1, true), "the file kept the line the log dropped")
                assert(text:find("blow number " .. (Combat.LOG_CAP + 100), 1, true), "and the last one")
            end)
        end,
    },
    {
        name = "turns announce themselves, so the file reads as rounds",
        fn = function()
            sandboxed(function()
                local combat = fakeCombat()
                local path = Trace.open(combat, { name = "rounds" })
                combat.turnCount = 1
                Combat.logEvent(combat, "move", "Stranger moves to (4, 6).")
                combat.turnCount = 2
                Combat.logEvent(combat, "damage", "Stranger strikes for 21.")
                local text = readTrace(path)
                assert(text:find("--- turn 1 ---", 1, true) and text:find("--- turn 2 ---", 1, true),
                    "each turn gets a heading")
            end)
        end,
    },
    {
        name = "closing writes how it ended and what everyone had left",
        fn = function()
            sandboxed(function()
                local combat = fakeCombat()
                local path = Trace.open(combat, { name = "ending" })
                combat.turnCount = 6
                combat.units[2].alive = false
                combat.units[2].char.stats.health.current = 0
                combat.units[1].char.stats.health.current = 41
                Trace.close("win")
                local text = readTrace(path)
                assert(text:find("result: win on turn 6", 1, true), "the ending is named, and when")
                -- "Won on turn 6 with both bodies above half" and "won on turn 6 with one standing"
                -- are the same word in the summary panel and completely different fights.
                assert(text:find("Stranger 41/62", 1, true), "what the party had left")
                assert(text:find("Demon Champion 0/150 (dead)", 1, true), "and what the far side did")
            end)
        end,
    },
    {
        name = "a summon called mid-fight is in the footer under the side that called it",
        fn = function()
            sandboxed(function()
                local combat = fakeCombat()
                local path = Trace.open(combat, { name = "summons" })
                combat.units[#combat.units + 1] = { side = "enemy", alive = true,
                    char = { name = "Bomblet", stats = { health = { current = 6, max = 6 } } } }
                Trace.close("win")
                assert(readTrace(path):find("Bomblet 6/6", 1, true),
                    "the footer reads the live unit list, not the roster the fight opened with")
            end)
        end,
    },
    {
        name = "the hook is armed only while a trace is open, so an untraced fight writes nothing",
        fn = function()
            sandboxed(function()
                assert(Combat.trace == nil, "nothing is recording before a trace opens")
                Trace.open(fakeCombat(), { name = "hook" })
                assert(Combat.trace ~= nil, "opening arms the hook in models/combat.lua")
                Trace.close("win")
                assert(Combat.trace == nil, "and closing disarms it")
            end)
            -- The seam the whole headless suite rests on: Combat.new does not open a trace, so the
            -- thousands of combats built by the specs around this one write no files at all.
            assert(Combat.trace == nil, "and the suite carries on with nothing recording")
        end,
    },
    {
        name = "a second open closes the first, so a retried fight is its own file",
        fn = function()
            sandboxed(function()
                -- Both opens land in the same second, which is the case that matters: a fight lost and
                -- retried at once. A second-resolution stamp alone named one file for both, and since
                -- open() truncates, the losing attempt was erased by the one replacing it -- the exact
                -- trace anybody would have gone looking for.
                local first = Trace.open(fakeCombat(), { name = "attempt" })
                local second = Trace.open(fakeCombat(), { name = "attempt" })
                assert(first ~= second, "the retry gets a file of its own")
                assert(readTrace(first):find("result: abandoned", 1, true),
                    "and the abandoned attempt is sealed rather than left trailing off mid-turn")
            end)
        end,
    },
    {
        name = "the folder is capped, so a long session does not fill the save directory",
        fn = function()
            sandboxed(function()
                Trace.KEEP = 3
                for _ = 1, 6 do Trace.open(fakeCombat(), { name = "capped" }) end
                Trace.close("win")
                -- Names are timestamp-first with a zero-padded counter behind it, so pruning is a plain
                -- sort that stays oldest-first even for six traces opened inside one second, and no
                -- file has to be stat'ed to know its age.
                assert(#love.filesystem.getDirectoryItems(TEST_DIR) <= Trace.KEEP,
                    "at most KEEP traces survive")
            end)
        end,
    },
    {
        name = "a release build traces nothing at all",
        fn = function()
            sandboxed(function()
                local was = Debug.enabled
                Debug.enabled = false
                local ok, path = pcall(Trace.open, fakeCombat(), { name = "release" })
                Debug.enabled = was
                assert(ok, "asking a release build to trace is not an error, it is a no-op")
                assert(path == nil, "it opens nothing")
                assert(Combat.trace == nil, "and arms nothing -- the rule in models/debug.lua holds")
            end)
        end,
    },
}
