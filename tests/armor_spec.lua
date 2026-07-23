-- Tests for the armor shelf and the movement economy it is priced against.
--
-- Two contracts live here, and they are the same contract read from two ends:
--
--   1. EVERY CLASS SHELF CARRIES ARMOR, and five pieces of each shelf's armor are quest-only -- `class`
--      with no `price` (docs/classes.md's "the tally, not the shelf"). A shelf whose armour is entirely
--      buyable has nothing to hand out for finishing its line; one that is entirely quest-locked cannot
--      be shopped at.
--
--   2. ARMOR MOVEMENT PENALTIES STACK, and cloth costs a square. Combat.applyUnitPassives sums
--      `bonus.movement` across the whole 3x3 grid, so a body wearing three coats pays for three coats.
--      That was always true and nothing asserted it, which is why the light tier could advertise "at no
--      cost to your pace" and quietly mean "wear four".
--
-- Pure logic, headless. Sweep style mirrors tests/class_spec.lua's weaponsOf().

local Item = require("models.item")
local Character = require("models.character")
local Combat = require("models.combat")

-- Five per shelf: the floor AND the intent. Stated as a constant so a shelf that grows keeps the same
-- promise rather than drifting to whatever it happened to be authored with.
local QUEST_ONLY_PER_SHELF = 5

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

-- Every armor blueprint on `class`'s shelf, as { id, def } pairs, sorted for a stable failure message.
--
-- SIGNATURES AND GENERALS' RELICS ARE OUTSIDE THE COUNT, exactly as tests/weapon_spec.lua's roster
-- rule holds them outside the families'. armor_sworn_aegis carries `class = "knight"` and no price and
-- would otherwise read as a sixth quest reward -- but it is `bound`, nailed to one character's centre
-- cell, and can never be earned, bought, stolen or moved. A shelf's quest-only count is a promise
-- about what finishing that vendor's line hands you, and a relic nobody can be handed is not part of
-- it.
local function armorsOf(class)
    local out = {}
    for id, def in pairs(Item.defs) do
        if def.type == "armor" and def.class == class
            and not (hasTag(def, "signature") or hasTag(def, "relic")) then
            out[#out + 1] = { id = id, def = def }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- A bare unit wearing exactly `ids`, folded through the real passive path. No arena, no battle: this
-- is the same function Combat.setup runs, called directly, so the numbers here are the live ones.
local function wearing(ids)
    local char = Character.instantiate("character_avatar")
    for i = #char.inventory, 1, -1 do char.inventory[i] = nil end
    for i, id in ipairs(ids) do char.inventory[i] = Item.instantiate(id) end
    local unit = { char = char, alive = true, x = 1, y = 1, side = "player" }
    Combat.refreshPassives(unit)
    return unit
end

return {
    {
        name = "every class shelf carries armor, and five pieces of it are quest-only",
        fn = function()
            for class in pairs(Item.CLASSES) do
                local armors = armorsOf(class)
                assert(#armors > 0, class .. " has no armor at all -- see docs/classes.md")
                local questOnly, buyable = {}, {}
                for _, a in ipairs(armors) do
                    if a.def.price then buyable[#buyable + 1] = a.id else questOnly[#questOnly + 1] = a.id end
                end
                assert(#questOnly == QUEST_ONLY_PER_SHELF,
                    class .. " has " .. #questOnly .. " quest-only armor(s), not " .. QUEST_ONLY_PER_SHELF
                        .. " -- a `class` with no `price` is the reward shape (docs/classes.md)")
                assert(#buyable > 0, class .. " sells no armor at all: its shelf cannot be shopped")
            end
        end,
    },
    {
        name = "a quest-only armor names a class and no price; a buyable one names both and a rank",
        fn = function()
            for class in pairs(Item.CLASSES) do
                for _, a in ipairs(armorsOf(class)) do
                    if a.def.price then
                        assert(a.def.repRank, a.id .. " is for sale with no repRank: nothing gates it")
                    else
                        assert(not a.def.repRank,
                            a.id .. " is quest-only but carries a repRank -- a rung on a shelf it is not on")
                    end
                end
            end
        end,
    },
    {
        name = "cloth costs a square of pace, every time it is woven",
        fn = function()
            for id, def in pairs(Item.defs) do
                if def.type == "armor" and hasTag(def, "cloth") then
                    local m = def.bonus and def.bonus.movement
                    assert(m == -1,
                        id .. " is cloth and its movement penalty is " .. tostring(m)
                            .. " -- cloth costs exactly one square (see armor_padded_vest)")
                end
            end
        end,
    },
    {
        name = "armor movement penalties stack across the grid",
        fn = function()
            -- The avatar's base, established first so the deltas below are read against a real number
            -- rather than a hardcoded one that a blueprint edit could silently invalidate.
            local bare = Combat.moveBudget(wearing({}))
            assert(bare == 4, "the avatar's base movement is 4, not " .. bare)

            local one = Combat.moveBudget(wearing({ "armor_padded_vest" }))
            assert(one == bare - 1, "one cloth vest costs one square (got " .. one .. ")")

            local two = Combat.moveBudget(wearing({ "armor_padded_vest", "armor_silk_robes" }))
            assert(two == bare - 2, "two cloth pieces cost two squares (got " .. two .. ")")

            local mixed = Combat.moveBudget(wearing({ "armor_iron_plate", "armor_chainmail" }))
            assert(mixed == bare - 3, "heavy (-2) plus medium (-1) is three squares (got " .. mixed .. ")")
        end,
    },
    {
        name = "over-armouring floors at planted, and never goes below it",
        fn = function()
            -- Four heavy plates is -8 against a base of 4. The budget must read 0, not -4: a negative
            -- budget means nothing to the Dijkstra, to Root, or to the reachable preview.
            local buried = wearing({ "armor_iron_plate", "armor_iron_plate", "armor_iron_plate", "armor_iron_plate" })
            assert(Combat.flatStat(buried, "movement") < 0, "the raw fold is allowed to go negative")
            assert(Combat.moveBudget(buried) == 0,
                "the budget floors at 0 (got " .. Combat.moveBudget(buried) .. ")")
        end,
    },
    {
        name = "the player starts in the coat the economy is tuned against",
        fn = function()
            local avatar = Character.instantiate("character_avatar")
            local found = false
            for _, item in ipairs(Character.eachItem(avatar)) do
                if item.name == Item.defs.armor_leather_armor.name then found = true end
            end
            assert(found, "the avatar starts wearing leather armor")
            -- Base 4 less the coat's square: the pace the prologue's enemies are cut to.
            local unit = { char = avatar, alive = true, x = 1, y = 1, side = "player" }
            Combat.refreshPassives(unit)
            assert(Combat.moveBudget(unit) == 3,
                "an avatar in its starting leather moves 3 (got " .. Combat.moveBudget(unit) .. ")")
        end,
    },
    {
        name = "exactly one armor sells a negative resist, and it is the wrath cuirass",
        fn = function()
            -- A negative `resist` AMPLIFIES the hit (Combat.mitigatedDamage sums the term without a
            -- floor). The mechanic is old -- utility_demonic_essence carries holy = -8 so Demon Bane
            -- has something to bite -- but that is a creature's flesh: noSteal, noCopy, nobody's
            -- choice. armor_reckless_cuirass is the only one a player can WEAR, and a second wearable
            -- one wants a header as loud as that file's before it lands here.
            local wearable, all = {}, {}
            for id, def in pairs(Item.defs) do
                for _, v in pairs(def.resist or {}) do
                    local first = type(v) == "table" and v[1] or v
                    if type(first) == "number" and first < 0 then
                        all[#all + 1] = id
                        if def.type == "armor" then wearable[#wearable + 1] = id end
                    end
                end
            end
            table.sort(wearable)
            assert(#wearable == 1 and wearable[1] == "armor_reckless_cuirass",
                "exactly one ARMOR carries a negative resist; found " .. #wearable
                    .. ": " .. table.concat(wearable, ", "))
            assert(#all == 2, "and the only other one is the demon's own flesh; found " .. #all)
        end,
    },
}
