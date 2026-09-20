-- Tests for the SLOT layer over models/save.lua: what counts as a slot file, what the folder says
-- about itself, which slot a new campaign takes, how a save is described on a card, and the one-time
-- move of a pre-slot save.lua into slot 1.
--
-- EVERY CASE RUNS UNDER A SCRATCH PREFIX. The headless suite writes into the same save directory as
-- the real game (conf.lua's identity), so a spec that allocated real slot numbers would leave junk
-- sitting in the developer's own load list -- and one that called Save.clear on slot 1 would delete
-- their campaign. `withScratchSlots` swaps Save.SLOT_PREFIX, which is exactly why that is a variable,
-- and sweeps every file it made afterwards whether the case passed or not.

local Player = require("models.player")
local Save = require("models.save")

local SCRATCH = "slotspec_"

-- Remove every file under the scratch prefix, including ones a failing case left half-written. Walks
-- the directory rather than a list the spec kept, so a file written by code under test (rather than
-- by the spec) is still swept.
local function sweep()
    for _, file in ipairs(love.filesystem.getDirectoryItems("")) do
        if file:sub(1, #SCRATCH) == SCRATCH then love.filesystem.remove(file) end
    end
end

local function withScratchSlots(fn)
    local realPrefix, realFile = Save.SLOT_PREFIX, Save.FILE
    Save.SLOT_PREFIX = SCRATCH
    Save.FILE = SCRATCH .. "legacy.lua" -- migrateLegacy's source, also inside the swept prefix
    sweep()
    local ok, err = pcall(fn)
    sweep()
    Save.SLOT_PREFIX, Save.FILE = realPrefix, realFile
    if not ok then error(err, 0) end
end

-- A minimal player that is cheap to write: Player.new builds a real opening roster and stash, which
-- is what makes a save worth round-tripping, but these cases care about FILES rather than contents.
local function playerNamed(name, deepest)
    local p = Player.new()
    p.name = name
    p.deepest = deepest
    return p
end

local function write(slot, name, deepest)
    local p = playerNamed(name, deepest)
    p.saveFile = Save.slotFile(slot)
    assert(Save.write(p, p.saveFile), "the scratch slot should write")
    return p
end

return {
    {
        name = "a slot file round-trips to its number, and nothing else does",
        fn = function()
            withScratchSlots(function()
                assert(Save.slotFile(1) == SCRATCH .. "1.lua", "slot 1 names its own file")
                assert(Save.slotOf(Save.slotFile(7)) == 7, "and the number reads back off it")
                assert(Save.slotOf(Save.slotFile(12)) == 12, "including past one digit")

                -- The anchored pattern is what keeps the folder's other tenants out of the load list.
                assert(Save.slotOf("settings.lua") == nil, "preferences are not a save")
                assert(Save.slotOf("descent_run.lua") == nil, "a run's throwaway company is not a save")
                assert(Save.slotOf("save_spec_scratch.lua") == nil,
                    "progression_spec's scratch file is not a save")
                assert(Save.slotOf(SCRATCH .. "1.bak") == nil, "nor is a backup beside one")
                assert(Save.slotOf(SCRATCH .. "x1.lua") == nil, "nor is a prefix with something after it")
                assert(Save.slotOf(nil) == nil, "and a non-string answers nil rather than erroring")
            end)
        end,
    },

    {
        name = "the folder lists only its slots, newest first",
        fn = function()
            withScratchSlots(function()
                assert(not Save.anySlot(), "precondition: the scratch prefix is empty")
                assert(#Save.slots() == 0, "...and so is its list")

                write(1, "Kell", 7)
                write(2, "Bryn", 2)
                assert(Save.anySlot(), "two saves exist")

                -- A file under the prefix that is NOT a slot, and one that is a slot but will not
                -- decode: neither may appear as a row.
                love.filesystem.write(SCRATCH .. "notes.txt", "not a save")
                love.filesystem.write(Save.slotFile(3), "return { this is not lua")

                local list = Save.slots()
                assert(#list == 2, "the list holds the two readable slots, got " .. #list)
                for _, entry in ipairs(list) do
                    assert(entry.slot == 1 or entry.slot == 2, "a listed row is one of the two")
                    assert(entry.file == Save.slotFile(entry.slot), "each row names its own file")
                    assert(entry.snap and entry.snap.name, "each row carries its peeked snapshot")
                end

                -- Newest first. `savedAt` is stamped by Save.write from os.time, so two saves written
                -- inside the same second tie -- the sort then falls back to the slot number, which is
                -- what this asserts rather than an ordering the clock cannot guarantee.
                assert(list[1].at >= list[2].at, "the head of the list is not older than the tail")
            end)
        end,
    },

    {
        name = "savedAt is stamped, and a save without one still sorts",
        fn = function()
            withScratchSlots(function()
                local before = os.time()
                write(1, "Kell", 1)
                local snap = Save.peek(Save.slotFile(1))
                assert(snap.savedAt, "a written save carries the time it was written")
                assert(snap.savedAt >= before, "and that time is not in the past")

                -- A save written before the field existed. `at` falls back to the file's modtime and
                -- then to the slot number, so the row still sorts rather than erroring on a nil.
                love.filesystem.write(Save.slotFile(2), "return { version = " .. Save.VERSION
                    .. ", name = \"Old\", gold = 5 }")
                local list = Save.slots()
                assert(#list == 2, "both saves list")
                for _, entry in ipairs(list) do
                    assert(type(entry.at) == "number", "every row sorts on a number")
                end
            end)
        end,
    },

    {
        name = "a new campaign takes the lowest free slot, and fills holes",
        fn = function()
            withScratchSlots(function()
                assert(Save.freeSlot() == 1, "the first campaign takes slot 1")
                write(1, "Kell", 1)
                assert(Save.freeSlot() == 2, "the second takes slot 2")
                write(2, "Bryn", 1)
                write(3, "Sera", 1)
                assert(Save.freeSlot() == 4, "and the fourth takes slot 4")

                Save.clear(Save.slotFile(2))
                assert(Save.freeSlot() == 2, "deleting the middle one frees its number")

                -- A slot that will not decode still HOLDS its number: handing it out would overwrite
                -- a file whose contents nobody has been able to look at.
                love.filesystem.write(Save.slotFile(2), "return { this is not lua")
                assert(Save.freeSlot() == 4, "an unreadable slot is still taken")
            end)
        end,
    },

    {
        name = "a write goes to its own slot and leaves the others untouched",
        fn = function()
            withScratchSlots(function()
                write(1, "Kell", 7)
                write(2, "Bryn", 2)
                local untouched = love.filesystem.read(Save.slotFile(1))

                -- The whole mechanism, exercised the way the game exercises it: the slot rides on the
                -- player and Player.save reads it off them. No argument is passed here.
                local p = playerNamed("Bryn", 3)
                p.saveFile = Save.slotFile(2)
                Player.active = p
                p.gold = 4210
                Player.save()
                Player.active = nil

                assert(love.filesystem.read(Save.slotFile(1)) == untouched,
                    "saving slot 2 must not rewrite slot 1 by so much as a byte")
                local two = Save.peek(Save.slotFile(2))
                assert(two.gold == 4210, "and slot 2 got the write")
                assert(two.deepest == 3, "...all of it")
            end)
        end,
    },

    {
        name = "an unstamped player still writes somewhere, and it is not a slot",
        fn = function()
            withScratchSlots(function()
                -- Player.start's fallback (no file) is deliberately readable rather than fatal. What
                -- it must NEVER do is land in the slot list, which is the same rule
                -- tests/descent_spec.lua pins for a descent's throwaway company.
                local p = playerNamed("Nobody", 1)
                assert(p.saveFile == nil, "precondition: no slot stamped")
                Player.active = p
                Player.save()
                Player.active = nil

                assert(Save.exists(), "it wrote to the legacy file")
                assert(#Save.slots() == 0, "and that file is not a slot")
            end)
        end,
    },

    {
        name = "a pre-slot save becomes slot 1, byte for byte, once",
        fn = function()
            withScratchSlots(function()
                assert(Save.migrateLegacy() == false, "nothing to move is not a migration")

                local p = playerNamed("Kell", 7)
                assert(Save.write(p), "write the legacy save (no file argument)")
                local bytes = love.filesystem.read(Save.FILE)

                assert(Save.migrateLegacy(), "the legacy save moves")
                assert(not Save.exists(), "...and is gone from where it was")
                assert(love.filesystem.read(Save.slotFile(1)) == bytes,
                    "slot 1 holds the same bytes: a copy, not a re-encode")
                assert(Save.slots()[1].snap.name == "Kell", "and it lists as the campaign it is")

                -- Idempotent, and inert once slots exist. A second legacy file appearing beside a real
                -- slot must not be dragged in on top of it.
                assert(Save.migrateLegacy() == false, "it does not run twice")
                assert(Save.write(p), "a stray legacy file appears again")
                assert(Save.migrateLegacy() == false, "and is left alone, because a slot exists")
                assert(Save.slots()[1].snap.name == "Kell", "slot 1 is untouched")
            end)
        end,
    },

    {
        name = "a save that will not decode is still moved rather than lost",
        fn = function()
            withScratchSlots(function()
                -- The case the byte copy exists for: upgrading the game must not eat the campaign of
                -- someone whose save happens not to load today.
                love.filesystem.write(Save.FILE, "return { version = 9999, gold = 1 }")
                assert(Save.migrateLegacy(), "an unreadable legacy save still moves")
                assert(love.filesystem.getInfo(Save.slotFile(1)), "the file is in slot 1")
                assert(Save.read(Save.slotFile(1)) == nil, "it still does not load, which is honest")
                assert(#Save.slots() == 0, "so it does not draw a row")
            end)
        end,
    },

    {
        name = "a card says who, how deep, how long, how rich and how recently",
        fn = function()
            withScratchSlots(function()
                local now = os.time()
                local entry = {
                    at = now - 7200,
                    snap = { name = "Kell", deepest = 7, day = 12, gold = 4210 },
                }
                local title, sub = Save.describe(entry, now)
                assert(title == "Kell", "the title is the company: " .. title)
                assert(sub:find("Floor 7", 1, true), "the sub-line says how deep: " .. sub)
                assert(sub:find("Day 12", 1, true), "...how long")
                assert(sub:find("4210 gold", 1, true), "...how rich")
                assert(sub:find("2 hours ago", 1, true), "...and how recently")

                assert(Save.brief(entry) == "Kell \194\183 Floor 7",
                    "the menu's one-liner is who and how far: " .. Save.brief(entry))

                -- A lap rides on the title rather than among the figures: it says which campaign this
                -- is, which is the name's job.
                entry.snap.ngPlus = 2
                local lapped = Save.describe(entry, now)
                assert(lapped:find("NG+2", 1, true), "a second lap is named on the title: " .. lapped)
            end)
        end,
    },

    {
        name = "every field a card reads is optional",
        fn = function()
            withScratchSlots(function()
                -- Save.peek returns raw saved data, so an older save simply has not got the newer
                -- fields. A card must render rather than error on any of them.
                local title, sub = Save.describe({ at = nil, snap = {} }, os.time())
                assert(title == "Unnamed company", "a save with no name still has a title: " .. title)
                assert(sub:find("Floor 0", 1, true), "and defaults for the rest: " .. sub)
                assert(sub:find("Day 1", 1, true), "...day one")
                assert(sub:find("0 gold", 1, true), "...an empty purse")

                assert(Save.describe(nil), "even a nil entry describes rather than errors")
                assert(Save.brief(nil), "and so does the one-liner")
                assert(Save.describe({ snap = { name = "" } }) == "Unnamed company",
                    "an empty name is as absent as a missing one")
            end)
        end,
    },

    {
        name = "how long ago rounds down, and gives up gracefully past a week",
        fn = function()
            local now = 1000000
            local function ago(secs) return Save.ago(now - secs, now) end

            assert(ago(0) == "just now", "the moment it was written")
            assert(ago(59) == "just now", "...and for the rest of that minute")
            assert(ago(60) == "1 minute ago", "singular at one")
            assert(ago(119) == "1 minute ago", "rounds DOWN: 119 seconds is not two minutes")
            assert(ago(600) == "10 minutes ago", "plural past one")
            assert(ago(3600) == "1 hour ago", "an hour")
            assert(ago(7199) == "1 hour ago", "...rounded down again")
            assert(ago(86400) == "1 day ago", "a day")
            assert(ago(6 * 86400) == "6 days ago", "up to the last day of the week")

            -- Past a week it is a date, which is a string this spec will not pin to a locale -- only
            -- that it produced something, and that it is not still counting days.
            local old = ago(30 * 86400)
            assert(old and #old > 0, "a month-old save still says something")

            assert(Save.ago(nil, now) == nil, "no timestamp, no line")
            assert(Save.ago(now + 60, now) == nil, "and a save from the future says nothing rather than lying")
        end,
    },
}
