-- Can the player actually GET it? One contract, and it has been unenforced since the shelf split in
-- two.
--
-- An item with a `class` and no `price` is quest-only by construction: no vendor stocks it
-- (Vendor.stock reads price), and Spoils.lootCandidates filters the random drop pool by price too, so
-- an unpriced item can never fall out of a fight either. That leaves exactly four ways one can reach a
-- player's hands -- a quest's `rewardItems`, a character's `startingItems` (recruit them, get their
-- grid), an encounter's authored `loot` list, or the player's own opening inventory.
--
-- Named by none of them, an unpriced item is DEAD DATA: it loads, it passes the schema, it tallies
-- toward a class in docs/classes.md's counts, tests/armor_spec.lua and tests/weapon_spec.lua both
-- count it toward their five-per-shelf promises -- and no save file can ever contain it. The counts
-- say "finish this vendor's line and you are handed these five"; this spec is what makes that a
-- promise rather than a claim.
--
-- BOUND items are exempt (`bound = true`): they are nailed to one character's centre cell and can
-- never be earned, bought, stolen or moved (Character.reconcileBound). armor_sworn_aegis is the
-- reference case, and tests/armor_spec.lua already holds them outside its own count for the same
-- reason. They arrive with the person or not at all.
--
-- Pure logic, headless.

local Item = require("models.item")
local Quest = require("models.quest")
local Character = require("models.character")
local Encounter = require("models.encounter")

local function hasTag(def, tag)
    for _, t in ipairs(def.tags or {}) do if t == tag then return true end end
    return false
end

-- Every item id the game can put in a player's hands without a shop or a loot roll, as a set.
local function obtainableIds()
    local got = {}

    local function add(list)
        for _, id in ipairs(list or {}) do
            -- `startingItems` is POSITIONAL: empty grid cells are `false`, not nil, so ipairs walks
            -- straight through them. Skip anything that is not an id.
            if type(id) == "string" then got[id] = true end
        end
    end

    for _, def in pairs(Quest.defs) do add(def.rewardItems) end
    for _, def in pairs(Character.defs) do add(def.startingItems) end
    for _, def in pairs(Encounter.defs) do add(def.loot) end
    add(require("data.player").startingItems)

    -- AND WHAT A CIRCLE'S BODIES PAY. This source was missing and the omission was invisible while the
    -- seven general relics were ALSO sitting in their generals' own `startingItems` -- the spec passed
    -- for the wrong reason, off a grid nobody can loot, rather than off the drop table that actually
    -- hands them over. It went red the moment the retired board's quest-only stock moved onto these
    -- lists and had no second home to be found in.
    -- AND WHAT THE RIFT GIVES UP ON ITS OWN. An unpriced item carries a `dropTier` now
    -- (tools/drop_tier.lua): the grade that would have set a priced item's shelf slot, spread
    -- along DEPTH instead, because an item with no shelf to sit on still has a place it belongs.
    -- Spoils.lootCandidates admits it once the company is that deep, so "quest-only" is no
    -- longer a synonym for unreachable -- which it became the moment the houses stopped posting
    -- quests and thirty-five of them were deleted.
    for id, def in pairs(Item.defs) do
        if def.dropTier then got[id] = true end
    end

    for _, drop in pairs(require("models.descent").DROPS or {}) do
        add(drop.general)
        add(drop.minor)
    end

    return got
end

-- Quest-only items, sorted, so a failure message is stable and diffable.
local function questOnly()
    local out = {}
    for id, def in pairs(Item.defs) do
        -- CREATURE KIT IS OUT, and it is the same set that was out before. This asks "gear a player is
        -- meant to be handed and can never actually get", and a wolf's teeth are not on that list --
        -- they were excluded by having no `class` at all, which is a state the fold ended
        -- (docs/class-fold.md). Naming the bucket is what that exclusion looks like written down.
        --
        -- Six items sit in the bucket and should not: ability_haste, ability_omnislash, ability_pull,
        -- armor_padded_vest, consumable_wildcraft_reagent and utility_decoy are ordinary player gear
        -- that happened to carry no class, so the creature pass swept them up. They are ALSO genuinely
        -- unreachable -- no price, no grant, no drop tier -- and that was true before this file could
        -- see them. Re-home them and this case will say so.
        if def.class and def.class ~= "creature" and not def.price and not def.bound then
            out[#out + 1] = id
        end
    end
    table.sort(out)
    return out
end

return {
    {
        name = "every quest-only item has a source that can actually hand it over",
        fn = function()
            local got = obtainableIds()
            local orphans = {}
            for _, id in ipairs(questOnly()) do
                if not got[id] then orphans[#orphans + 1] = id end
            end
            assert(#orphans == 0, #orphans .. " unpriced item(s) no source can grant -- "
                .. "give each a quest's rewardItems, a character's startingItems, or an encounter's "
                .. "loot, or price it: " .. table.concat(orphans, ", "))
        end,
    },
    {
        -- The other direction: a quest that hands over an id nothing defines pays out nothing and
        -- says nothing, silently. Player.grantItem drops unknown ids rather than raising, so this is
        -- exactly the kind of typo that survives to a save file.
        name = "every rewardItems id names a real item",
        fn = function()
            local bad = {}
            for questId, def in pairs(Quest.defs) do
                for _, id in ipairs(def.rewardItems or {}) do
                    if not Item.defs[id] then bad[#bad + 1] = questId .. " -> " .. tostring(id) end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "quest reward(s) naming no known item: " .. table.concat(bad, ", "))
        end,
    },
}
