-- Tests for models/bestiary.lua: THE BOOK, the chase board (docs/drops.md).
--
-- Named bestiary_BOOK rather than bestiary_spec because tests/bestiary_spec.lua is taken and is about
-- something else entirely -- the tier/discipline contract every enemy blueprint stands on
-- (docs/bestiary.md). Two different meanings of one word, two files.
--
-- The claim that matters is the REDACTION -- a met body shows every row on its drop list, and a row the
-- company has not carried out is struck rather than absent. An entry that hid what you were missing
-- would be a record of what you have, which is the thing the author denied in favour of this.

local Bestiary = require("models.bestiary")
local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Save = require("models.save")
local Spoils = require("models.spoils")

-- A bare company. It carries ONE roster member deliberately: Save.restore refuses a save with an empty
-- roster ("nothing left to play with"), so a fixture without a body round-trips as nil and the save
-- case below would be asserting about a failure it caused itself.
local function bare()
    return {
        gold = 0, materials = {}, stash = {}, found = {}, met = {},
        roster = { Character.instantiate("character_avatar") },
    }
end

-- A body that actually carries an authored list, chosen by scanning so the fixture survives a re-deal
-- by tools/drop_assign.lua rather than pinning an id that moved.
local function bodyWithDrops()
    local ids = {}
    for id in pairs(Character.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local def = Character.defs[id]
        if def.drops and #def.drops > 1 then return id, def end
    end
end

return {
    {
        -- The catalogue has to actually carry lists, or every case below is green over an empty set.
        name = "the catalogue carries authored drop lists",
        fn = function()
            local n = 0
            for _, def in pairs(Character.defs) do
                if def.drops and #def.drops > 0 then n = n + 1 end
            end
            assert(n > 20, "only " .. n .. " bodies carry a drops list -- run `. drop-assign apply`")
        end,
    },
    {
        name = "a body is met once, and meeting it again changes nothing",
        fn = function()
            local player = bare()
            local id = bodyWithDrops()
            assert(not Bestiary.hasMet(player, id), "not met yet")
            assert(Bestiary.markMet(player, id), "the first meeting is new")
            assert(Bestiary.hasMet(player, id), "and it sticks")
            assert(not Bestiary.markMet(player, id), "the second is not new")
        end,
    },
    {
        -- MET MEANS FOUGHT, and a roster is what a fight hands over -- the same shape the spoils roll
        -- takes, so the two read one list.
        name = "a beaten roster stamps every body in it",
        fn = function()
            local player = bare()
            local id = bodyWithDrops()
            local units = { { char = { id = id } }, { char = { id = id } },
                { char = { id = "character_bandit" } } }
            assert(Bestiary.recordMet(player, units) == 2, "two distinct bodies were new")
            assert(Bestiary.hasMet(player, "character_bandit"), "the bandit was met too")
        end,
    },
    {
        -- THE REDACTION, which is the whole feature. Every row on a met body's list is listed; the ones
        -- not carried out are marked unfound rather than hidden, because the hole IS the signal.
        name = "an entry lists every drop, and marks the ones not carried out",
        fn = function()
            local player = bare()
            local id, def = bodyWithDrops()
            Bestiary.markMet(player, id)

            local rows = Bestiary.dropRows(player, id)
            assert(#rows == #def.drops, "every authored row is listed: got " .. #rows
                .. " of " .. #def.drops)
            for _, row in ipairs(rows) do
                assert(row.found == false, "nothing is carried out yet, so every row is redacted")
                assert(row.name and row.name ~= "", "a redacted row still knows its name to strike")
            end

            -- Carry one out, and exactly that row becomes legible.
            Player.markFound(player, def.drops[1])
            rows = Bestiary.dropRows(player, id)
            assert(rows[1].found or rows[2].found, "the carried piece reads as found")
            local foundCount = 0
            for _, row in ipairs(rows) do if row.found then foundCount = foundCount + 1 end end
            assert(foundCount == 1, "exactly one row turned, got " .. foundCount)
        end,
    },
    {
        name = "progress counts what is still struck out",
        fn = function()
            local player = bare()
            local id, def = bodyWithDrops()
            Bestiary.markMet(player, id)
            local found, total = Bestiary.progress(player, id)
            assert(found == 0 and total == #def.drops, "nothing found, everything listed")

            for _, itemId in ipairs(def.drops) do Player.markFound(player, itemId) end
            found, total = Bestiary.progress(player, id)
            assert(found == total and total > 0, "a fully-carried body reads complete")
            for _, entry in ipairs(Bestiary.entries(player)) do
                if entry.id == id then assert(entry.complete, "and says so on the entry") end
            end
        end,
    },
    {
        -- A creature carries natural weapons only (docs/bestiary.md's split), so its entry has nothing
        -- struck out -- which must read as "nothing to come back for" rather than as "nothing found".
        name = "a body with no list has nothing to go back for",
        fn = function()
            local player = bare()
            local creature
            for id, def in pairs(Character.defs) do
                if not def.drops and (def.kind == "beast" or def.kind == "elemental") then
                    creature = id; break
                end
            end
            assert(creature, "the catalogue must hold a creature with no authored list")
            Bestiary.markMet(player, creature)
            local found, total = Bestiary.progress(player, creature)
            assert(found == 0 and total == 0, "no list means no redactions")
            for _, entry in ipairs(Bestiary.entries(player)) do
                if entry.id == creature then
                    assert(not entry.complete, "an empty list is not a completed one")
                end
            end
        end,
    },
    {
        -- The book lists what you have SEEN, never the contents of data/characters -- otherwise it is a
        -- spoiler sheet rather than a record.
        name = "the book lists only what has been met",
        fn = function()
            local player = bare()
            assert(#Bestiary.entries(player) == 0, "a company that has met nothing has an empty book")
            Bestiary.markMet(player, bodyWithDrops())
            assert(#Bestiary.entries(player) == 1, "and exactly what it has met after that")
        end,
    },
    {
        -- An id that left data/ must drop out rather than leaving an entry the book cannot draw.
        name = "an unknown body is never entered",
        fn = function()
            local player = bare()
            assert(not Bestiary.markMet(player, "character_that_never_was"),
                "a body with no blueprint is not a meeting")
            assert(#Bestiary.entries(player) == 0, "and leaves no entry")
        end,
    },
    {
        -- Additive on the save, like `found` and `visitedVendors` beside it: an older save loads having
        -- met nothing and fills in again on its next fight.
        name = "the met ledger survives a save round trip",
        fn = function()
            local player = bare()
            local id = bodyWithDrops()
            Bestiary.markMet(player, id)
            local snap = Save.snapshot(player)
            assert(snap.met and snap.met[id], "the snapshot carries the ledger")
            local back = Save.restore(snap)
            assert(Bestiary.hasMet(back, id), "and a restore brings it back")
            assert(#Bestiary.entries(back) == 1, "with its entry intact")
        end,
    },
}
