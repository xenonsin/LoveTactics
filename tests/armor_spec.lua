-- Tests for the armor shelf and the movement economy it is priced against.
--
-- Two contracts live here, and they are the same contract read from two ends:
--
--   1. EVERY CLASS SHELF CARRIES ARMOR, and five pieces of each shelf's armor are quest-only -- `class`
--      with no `price` (docs/classes.md's "the tally, not the shelf"). A shelf whose armour is entirely
--      buyable has nothing to hand out for finishing its line; one that is entirely quest-locked cannot
--      be shopped at.
--
--   2. ARMOR MOVEMENT PENALTIES STACK, and every coat costs a square. Combat.applyUnitPassives sums
--      `bonus.movement` across the whole 3x3 grid, so a body wearing three coats pays for three coats.
--      That was always true and nothing asserted it, which is why the light tier could advertise "at no
--      cost to your pace" and quietly mean "wear four". Cloth was pinned to -1 first; the free rung the
--      leather, hide and shield pieces were sitting on is gone now too, and the floor is -1 for
--      everything, -2 for heavy. What a tier buys is protection, never a pace you don't feel.
--
-- Pure logic, headless. Sweep style mirrors tests/class_spec.lua's weaponsOf().

local Item = require("models.item")
local Class = require("models.class") -- roots(): the seven shelves, since the fold (docs/class-fold.md)
local Character = require("models.character")
local Combat = require("models.combat")

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
        -- EVERYTHING UNDER THE HOUSE, not only what names it exactly. An earned class's armour is
        -- still that house's rack -- a Mammonite coat is rogue armour -- and before the fold it
        -- literally said `class = "rogue"` with the mammonite in a second field. One field now
        -- (docs/class-fold.md), so the descent is asked of the class rather than read off the item.
        if def.type == "armor" and Class.descendsFrom(def.class, class)
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
        -- ARMOR IS FOUND NOW, ALL OF IT. The shelf recut kept a price on three things only -- abilities,
        -- consumables, and a house's opener weapon (tools/drop_tier.lua) -- so the split this case used
        -- to measure, five quest-only pieces against a buyable rack, has no buyable half left to
        -- measure against. What replaces it is the promise that actually matters: every house has armor
        -- to be found, and every piece of it has a depth to be found at, so none of it is unreachable.
        name = "every class shelf carries armor, and all of it is found in the rift",
        fn = function()
            for class in pairs(Class.roots()) do
                local armors = armorsOf(class)
                assert(#armors > 0, class .. " has no armor at all -- see docs/classes.md")
                for _, a in ipairs(armors) do
                    assert(not a.def.price,
                        a.id .. " still carries a price -- armor is found, not stocked (docs/shelf.md)")
                    assert(a.def.dropTier or a.def.bound,
                        a.id .. " has neither a price nor a depth: it can never reach a player")
                end
            end
        end,
    },
    {
        -- A RUNG ON AN UNPRICED WARE IS NOT DEAD DATA ANY MORE, and this case used to say it was. The
        -- rung is the item's GRADE RANK -- what models/balance.lua reads as its power level -- and it
        -- was only ever ALSO a shelf gate. The recut took the price and left the rank, and the gate
        -- moved to a different question entirely: have you carried one out (models/vendor.lua). So what
        -- an armor piece owes is a rank, always, and a price never.
        name = "every armor names a class and a rank, and none of it is for sale",
        fn = function()
            for class in pairs(Class.roots()) do
                for _, a in ipairs(armorsOf(class)) do
                    assert(not a.def.price,
                        a.id .. " is for sale -- armor is found now (tools/drop_tier.lua)")
                    -- A RANK OR A DEPTH, and either will do. Everything the recut moved kept its
                    -- `unlockQuests` -- that is the grade position models/balance.lua measures against.
                    -- The pieces that were quest-only long before the recut never had one and grade at
                    -- the opening rung, which is a settled position and not this case's argument.
                    assert(a.def.unlockQuests ~= nil or a.def.dropTier or a.def.bound,
                        a.id .. " has neither a rank nor a depth: nothing places it at all")
                end
            end
        end,
    },
    {
        name = "every armor costs a square of pace, and heavy costs two",
        fn = function()
            -- THERE IS NO FREE TIER. The cost table used to have a 0 rung ("leather / hide cut for
            -- movement") and a floor of 0, which meant the honest way to read the whole spread was
            -- "find the pieces that are free and wear those" -- and because penalties stack, four
            -- free pieces was a real build. Every coat is felt now; what separates the tiers is how
            -- much it protects, not whether you notice it (docs/classes.md, armor_padded_vest).
            --
            -- Shields and relics are inside this rule, not beside it. A shield is worn, and a rule
            -- with a carve-out for the one item class that wanted one is not a cost table.
            for id, def in pairs(Item.defs) do
                if def.type == "armor" then
                    local m = def.bonus and def.bonus.movement
                    assert(type(m) == "number" and m <= -1,
                        id .. "'s movement penalty is " .. tostring(m)
                            .. " -- every armor costs at least one square (docs/classes.md)")
                    if hasTag(def, "heavy") then
                        assert(m <= -2,
                            id .. " is heavy and costs " .. m .. " -- the heavy tier costs two squares")
                    end
                end
            end
        end,
    },
    {
        name = "every armor buys that square with defense or with a resist",
        fn = function()
            -- The other half of the trade. A piece that slows you and protects nothing is not a
            -- choice with a downside, it is a trap -- and the movement floor above is exactly the
            -- kind of change that could leave one behind.
            for id, def in pairs(Item.defs) do
                if def.type == "armor" then
                    local b = def.bonus or {}
                    local guards = (b.defense or b.magicDefense) ~= nil
                    for _, v in pairs(def.resist or {}) do
                        local first = type(v) == "table" and v[1] or v
                        if type(first) == "number" and first > 0 then guards = true end
                    end
                    assert(guards,
                        id .. " costs pace and returns neither defense, magicDefense, nor a positive resist")
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
