-- Tests for THE COLD FORGE: the road stop that raises one carried piece a rung for nothing
-- (data/encounters/encounter_cold_forge.lua, the branch in states/game.lua, ui/panels/anvil.lua).
--
-- The model half is models/forge.lua's Forge.equipped / Forge.grantRefusal / Forge.grant, and what
-- these cases are really about is the ONE line that separates a gift from a cheat: the bill is waived
-- and the ceiling is not. Headless.

local Character = require("models.character")
local Class = require("models.class")
local Encounter = require("models.encounter")
local Forge = require("models.forge")
local Item = require("models.item")
local Player = require("models.player")

-- A company that owns nothing and has climbed nowhere: no gold, no materials, no technique. Exactly the
-- state a free rung has to work in, and exactly the state that must not buy depth.
local function pauper()
    local p = Player.new()
    p.gold = 0
    p.materials = {}
    p.roster = { Character.instantiate("character_knight") }
    for i = 1, Character.MAX_INVENTORY do p.roster[1].inventory[i] = nil end
    return p
end

-- The first upgradable item on the shelf belonging to a ROOT class, as an id. Root, because that is the
-- half of the shelf Forge.ceilingFor actually puts a ceiling on -- an earned class's gear has none, so a
-- test about the ceiling built on one would pass without ever reaching the rule.
local function rootClassItemId()
    local ids = {}
    for id, def in pairs(Item.defs) do
        if def.class and Class.defs[def.class] and Class.isRoot(def.class)
            and Item.isUpgradable(Item.instantiate(id)) and Forge.canWork(Item.instantiate(id)) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids) -- pairs() order is not promised across builds; the spec must pick the same item twice
    return ids[1]
end

-- The first upgradable item with NO ceiling on it, so a case about the bill is never accidentally a
-- case about standing. Since the class fold every item on the shelf belongs to a class
-- (docs/class-fold.md), so "no ceiling" means an EARNED one -- Forge.ceilingFor hands those the top
-- outright and lets the technique price be the only brake.
local function unceiledItemId()
    local ids = {}
    for id, def in pairs(Item.defs) do
        if def.class and Class.isEarned(def.class) and Item.isUpgradable(Item.instantiate(id))
            and Forge.canWork(Item.instantiate(id)) then
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return ids[1]
end

local function readFile(path)
    local f = assert(io.open(path, "r"), "cannot read " .. path)
    local src = f:read("*a")
    f:close()
    return src
end

return {
    -- -----------------------------------------------------------------------
    -- What the forge can reach
    -- -----------------------------------------------------------------------
    {
        name = "the forge reaches what the company is CARRYING and never the stash",
        fn = function()
            local p = pauper()
            local id = unceiledItemId() or rootClassItemId()
            assert(id, "the shelf has nothing a level can improve")

            local carried = Item.instantiate(id, 1, 0)
            p.roster[1].inventory[1] = carried
            p.stash = { Item.instantiate(id, 1, 0) }

            local found = Forge.equipped(p)
            assert(#found == 1, "expected exactly the one carried piece, got " .. #found)
            assert(found[1].item == carried, "the entry must be the grid's own instance, not a copy")
            assert(found[1].cell == 1 and found[1].char == p.roster[1],
                "an entry has to say which cell it came out of -- that is where the new one goes back")

            -- The bench in the city works on the stash too (ForgePanel:collect); the road does not, and
            -- that difference is the whole reason this collector exists rather than reusing that one.
            for _, e in ipairs(found) do
                assert(e.item ~= p.stash[1], "the stash is out of the road's reach")
            end
        end,
    },
    {
        name = "consumables are not on the anvil -- a stack of five potions is not five things to hammer",
        fn = function()
            local p = pauper()
            local potion
            for id, def in pairs(Item.defs) do
                if def.type == "consumable" and (potion == nil or id < potion) then potion = id end
            end
            if not potion then return end -- no consumables authored: nothing to assert
            p.roster[1].inventory[1] = Item.instantiate(potion, 1, 0)
            assert(#Forge.equipped(p) == 0,
                "a consumable refines per recipe at the bench and must not be offered a rung out here")
        end,
    },

    -- -----------------------------------------------------------------------
    -- The bill is waived
    -- -----------------------------------------------------------------------
    {
        name = "a rung costs nothing: no gold, no technique, no stock",
        fn = function()
            local p = pauper()
            local id = unceiledItemId()
            assert(id, "no unceilinged upgradable stock to test the free rung on")
            local item = Item.instantiate(id, 1, 0)
            p.roster[1].inventory[1] = item

            -- The same rung SOLD is a real bill, which is what makes "free" mean something here.
            local billed = Forge.upgradeCost(p, item)
            assert(billed, "the bench should still be able to price this rung")
            local owed = (billed.gold or 0) + (billed.technique or 0)
            for _, n in pairs(billed.materials or {}) do owed = owed + n end
            assert(owed > 0, "the fixture is broken: this rung is free at the bench too, so nothing is proven")

            local fresh = assert(Forge.grant(p, item), "a pauper must still be able to take the free rung")
            assert(fresh.level == 1, "one rung, from 0 to 1 -- got +" .. tostring(fresh.level))
            assert(fresh ~= item, "an upgrade bakes a NEW instance from the blueprint (Item.instantiate)")
            assert(fresh.name:find("%+1$"), "the level rides on the name: " .. tostring(fresh.name))
            assert(p.gold == 0, "the road charged gold for a gift")
            for _, n in pairs(p.materials or {}) do
                assert(n == 0, "the road charged materials for a gift")
            end
        end,
    },
    {
        name = "one rung and no more -- the gift's size is not the player's to set",
        fn = function()
            local p = pauper()
            local id = unceiledItemId()
            local item = Item.instantiate(id, 1, 4)
            p.roster[1].inventory[1] = item
            local fresh = assert(Forge.grant(p, item))
            assert(fresh.level == 5, "a grant steps exactly one rung; got +" .. tostring(fresh.level))
        end,
    },

    -- -----------------------------------------------------------------------
    -- ...and the ceiling is not
    -- -----------------------------------------------------------------------
    {
        name = "the road cannot hand over depth the company has not climbed to",
        fn = function()
            local p = pauper()
            local id = rootClassItemId()
            assert(id, "no root-class upgradable stock: the ceiling rule cannot be exercised")

            -- A company standing at the bottom of every class ladder tops out at Forge.CEILING_BASE.
            local ceiling = Forge.ceilingFor(p, Item.instantiate(id, 1, 0))
            assert(ceiling < Item.MAX_LEVEL,
                "the fixture is broken: an unplayed company should not already be at the top")

            local atCeiling = Item.instantiate(id, 1, ceiling)
            p.roster[1].inventory[1] = atCeiling
            local fresh, reason = Forge.grant(p, atCeiling)
            assert(fresh == nil, "a free rung past the ceiling is the bench's job sold off at the roadside")
            assert(reason == "locked", "expected 'locked', got " .. tostring(reason))
            assert(atCeiling.level == ceiling, "a refused grant must not have touched the item")

            -- ...and the rung BELOW it is still given, so the ceiling is a ceiling and not a closed door.
            local under = Item.instantiate(id, 1, math.max(0, ceiling - 1))
            p.roster[1].inventory[1] = under
            assert(Forge.grant(p, under), "everything under the ceiling is still free to take")
        end,
    },
    {
        name = "a fully forged piece has no rung left to give",
        fn = function()
            local p = pauper()
            local id = unceiledItemId()
            local topped = Item.instantiate(id, 1, Item.MAX_LEVEL)
            p.roster[1].inventory[1] = topped
            local fresh, reason = Forge.grant(p, topped)
            assert(fresh == nil and reason == "max level",
                "expected 'max level', got " .. tostring(reason))
        end,
    },

    -- -----------------------------------------------------------------------
    -- The list and the commit are one answer
    -- -----------------------------------------------------------------------
    {
        name = "every row the panel draws bright is a rung the grant actually gives",
        fn = function()
            -- THE DEFECT THIS GUARDS is a row drawn live and refused on the button, or greyed for a
            -- reason the commit does not share. The panel colours a card off Forge.grantRefusal and
            -- Forge.grant re-asks the same function, so the two cannot drift -- this walks the whole
            -- shelf at two standings and holds them to it.
            for _, level in ipairs({ 0, Class.CLASS_LEVEL_CAP }) do
                local p = pauper()
                local bank = Class.classLevelCost(level)
                p.roster[1].technique = setmetatable({}, { __index = function() return bank end })
                p.roster[1].techniqueSpent = {}

                local ids = {}
                for id in pairs(Item.defs) do ids[#ids + 1] = id end
                table.sort(ids)
                for _, id in ipairs(ids) do
                    for _, at in ipairs({ 0, 3, Item.MAX_LEVEL }) do
                        local item = Item.instantiate(id, 1, at)
                        local refusal = Forge.grantRefusal(p, item)
                        local fresh, reason = Forge.grant(p, item)
                        assert((refusal == nil) == (fresh ~= nil),
                            id .. " +" .. at .. ": the list says "
                                .. (refusal and ("'" .. refusal .. "'") or "yes")
                                .. " and the strike says " .. (fresh and "yes" or "no"))
                        assert(refusal == reason,
                            id .. " +" .. at .. ": greyed for '" .. tostring(refusal)
                                .. "' and refused for '" .. tostring(reason) .. "'")
                    end
                end
            end
        end,
    },

    -- -----------------------------------------------------------------------
    -- The stop
    -- -----------------------------------------------------------------------
    {
        name = "the Cold Forge is a stop, not a fight, and it holds off the first floor",
        fn = function()
            local def = Encounter.get("encounter_cold_forge")
            assert(def, "encounter_cold_forge missing from the registry")
            assert(def.kind == "anvil", "the branch in states/game.lua keys on 'anvil'")
            assert(not Encounter.opensBattle({ kind = def.kind }),
                "the Cold Forge must never wear the combat border")

            local function has(pool)
                for _, e in ipairs(pool) do if e.id == "encounter_cold_forge" then return e end end
                return nil
            end
            assert(not has(Encounter.pool({ day = 1, biome = "forest" })),
                "on the opening floor every piece is at +0 and the rungs all look alike")
            local seated = has(Encounter.pool({ day = 2, biome = "forest" }))
            assert(seated and seated.weight > 0, "it should be drawable from the second day down")

            -- An uncommon FIND, not a fixture of the road: well under what an ordinary fight carries.
            local combat = 0
            for _, e in ipairs(Encounter.pool({ day = 4, biome = "forest" })) do
                if e.kind == "combat" and e.weight > combat then combat = e.weight end
            end
            assert(combat == 0 or seated.weight < combat,
                "a free rung must stay rarer than an ordinary fight")
        end,
    },
    {
        name = "every non-fight stop has its own colour and its own mark on the map",
        fn = function()
            -- A SOURCE SCAN, and it is derived from the blueprints rather than from a list written here,
            -- because the failure it guards is a kind being ADDED with no marker. That is not
            -- hypothetical: the Weeping Stone shipped without either, fell through markerColor to the
            -- combat red and through the MarkerIcon table to the crossed swords, and so the one stop
            -- that sells a rare relic was drawn as an ordinary skirmish. See Encounter.opensBattle's
            -- header: a marker that promises a fight the state does not run is a lie the player only
            -- finds out by walking there.
            --
            -- Fights are the exemption and the only one: combat and elite are what the fallbacks at the
            -- bottom of markerColor and MarkerIcon are FOR.
            local src = readFile("ui/overworld_map.lua")
            local kinds = {}
            for _, def in pairs(Encounter.defs) do
                if def.kind and not Encounter.opensBattle({ kind = def.kind, composition = {} }) then
                    kinds[def.kind] = true
                end
            end
            local missing = {}
            for kind in pairs(kinds) do
                if not src:find('kind == "' .. kind .. '"', 1, true) then
                    missing[#missing + 1] = kind .. " (no markerColor)"
                elseif not src:find("function MarkerIcon." .. kind .. "(", 1, true) then
                    missing[#missing + 1] = kind .. " (no MarkerIcon)"
                end
            end
            table.sort(missing)
            assert(#missing == 0,
                "these stops are drawn as ordinary fights: " .. table.concat(missing, ", "))
        end,
    },
}
