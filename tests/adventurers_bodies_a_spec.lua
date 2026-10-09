-- THE RIFT'S ADVENTURERS, SLICE A: the race-free bodies for fourteen classes (the seven roots, and one
-- subclass under each: warlord, bulwark, thief, beastmaster, elementalist, exorcist, bombardier). tests/adventurers_spec.lua
-- holds every body to the shared contract; this holds THESE fourteen to the one thing that contract cannot
-- see from the blueprint -- that each one, fielded as two different races, arms a real action and its AI
-- takes a turn on a bare board rather than standing there.
--
-- The races are picked off the leaning list, skipping a race that has a race item for the class: those
-- items are another slice's, and a body spec that reddened on a missing item would be measuring the
-- wrong thing. A pairing whose item does exist is fielded too, so the merged tree covers it.

local Adventurers = require("models.adventurers")
local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local CLASSES = {
    "fighter", "knight", "rogue", "hunter", "mage", "priest", "alchemist",
    "warlord", "bulwark", "thief", "beastmaster", "elementalist", "exorcist", "bombardier",
}
local ROOTS = { fighter = true, knight = true, rogue = true, hunter = true, mage = true, priest = true,
    alchemist = true }

-- Two races with no race item for `class`, leaning ones first.
local function plainRaces(class)
    local out, seen = {}, {}
    local function try(race)
        if #out < 2 and not seen[race] and not Adventurers.raceItemOf(race, class) then
            seen[race] = true
            out[#out + 1] = race
        end
    end
    for _, r in ipairs(Adventurers.leaningRaces(class)) do try(r) end
    try("goblin")
    for _, r in ipairs(Adventurers.RACES) do try(r) end
    return out
end

local function racesFor(class)
    local races = plainRaces(class)
    for _, race in ipairs(Adventurers.RACES) do
        local itemId = Adventurers.raceItemOf(race, class)
        if itemId and Item.defs[itemId] then races[#races + 1] = race end
    end
    return races
end

-- One turn of `id` on a bare 9x9, a bandit `gap` tiles off and a bandit of its own beside it.
local function planAt(id, gap)
    local combat = Fixture.combat(Fixture.new(9, 9),
        { Fixture.unit("character_bandit", 5, 3 + gap) },
        { Fixture.unit(id, 5, 3), Fixture.unit("character_bandit", 4, 2) })
    return AI.plan(combat, combat.units[2]), combat.units[2]
end

return {
    { name = "slice A's fourteen bodies are adventurers on the right rung, class and discipline", fn = function()
        for _, class in ipairs(CLASSES) do
            local id = Adventurers.bodyOf(class)
            local def = rawget(Character.defs, id)
            assert(def, "no body " .. id)
            assert(def.adventurer == true and not def.boss and not def.drops, id .. " is not plain traffic")
            assert(def.tier == (ROOTS[class] and 1 or 2), id .. " is on rung " .. tostring(def.tier))
            assert(def.race == Adventurers.leaningRaces(class)[1], id .. " loads as the wrong race")
            if ROOTS[class] then
                assert(def.class == class and not def.discipline, id .. " should walk its root bare")
            else
                assert(def.discipline == class, id .. " should claim " .. class)
            end
            local cells = 0
            for i, entry in ipairs(def.startingItems) do
                cells = i
                assert(Item.defs[entry], id .. " carries an unknown item " .. tostring(entry))
            end
            assert(cells == #def.startingItems and cells <= 7, id .. "'s kit is not 7 contiguous cells")
        end
    end },

    { name = "each body fields as two races with its default action armed", fn = function()
        for _, class in ipairs(CLASSES) do
            local races = racesFor(class)
            assert(#races >= 2, class .. " found fewer than two races to field")
            for _, race in ipairs(races) do
                local id = Adventurers.variantId(class, race)
                local char = Character.instantiate(id)
                assert(char.race == race, id .. " lost its race")
                local unit = { char = char, x = 1, y = 1, side = "enemy", alive = true }
                local act = Combat.defaultAction(char, unit)
                assert(act and act ~= char.unarmed and act.id == Character.defs[id].defaultAction,
                    id .. " arms " .. tostring(act and act.id) .. " instead of its default action")
            end
        end
    end },

    { name = "each body's AI takes an action on a bare board", fn = function()
        for _, class in ipairs(CLASSES) do
            local id = Adventurers.variantId(class, plainRaces(class)[2])
            local acted
            for _, gap in ipairs({ 1, 2, 3 }) do
                local plan = planAt(id, gap)
                if plan.item then acted = plan.item.id break end
            end
            assert(acted, id .. " found nothing to do with a foe one, two or three tiles off")
        end
    end },

    { name = "the bulwark shoves whichever neighbour has fire behind it", fn = function()
        -- The `hazardous` preference (models/ai.lua): two bandits flank it, fire burns behind one, and
        -- the shove goes that way whichever side the fire is on.
        local Hazard = require("models.hazard")
        for _, side in ipairs({ { burn = { 3, 2 }, want = 4 }, { burn = { 7, 8 }, want = 6 } }) do
            local combat = Fixture.combat(Fixture.new(9, 9),
                { Fixture.unit("character_bandit", 4, 3), Fixture.unit("character_bandit", 6, 3) },
                { Fixture.unit("character_adv_bulwark@naga", 5, 3) })
            for _, x in ipairs(side.burn) do
                Hazard.place(combat, x, 3, "hazard_fire", { duration = 10, amount = 5 })
            end
            local plan = AI.plan(combat, combat.units[3])
            assert(plan.item and plan.tx == side.want and plan.ty == 3, "the bulwark struck "
                .. tostring(plan.tx) .. "," .. tostring(plan.ty) .. " rather than the body by the fire")
        end
    end },

    { name = "the knight taunts what reaches it", fn = function()
        local plan = planAt("character_adv_knight@naga", 1)
        assert(plan.item and plan.item.id == "ability_provoke", "the knight did not Provoke: "
            .. tostring(plan.item and plan.item.id))
    end },
}
