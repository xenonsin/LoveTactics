-- THE PLANNER TAKES A SHAPE, CALLS AN ELEMENTAL AND SETS A TRAP (2026-10-09). Three verbs no AI body had
-- ever used, measured on the bodies that carry them as their signature: the druid's Wild Shape (the dry
-- run had no `transform`, so the cast previewed as nothing), the summoner's elementals and the trapper's
-- Bear Trap (both aim at EMPTY ground, which the planner never offered until `aiAims`, and land no entry
-- the turn they are cast, which only `aiPlants` credits). Each case is a bare board and one foe at the
-- distance the body's own rule asks for, so what is being pinned is the turn the rule promises.
--
-- A PLANT IS CAST ONLY BY A RULE THAT NAMES IT (models/ai.lua's `namedByRule`). The generic templates in
-- Descent.COMPANY carry a wolf, a fire elemental and a spike trap with no rule naming any of them; when
-- the free planner could aim them, the company's archer called a wolf and the Strongroom went from 32
-- unit-turns to 51, and Sloth's Heave ran past the skirmish budget. The measuring stick stays as it was.

local Adventurers = require("models.adventurers")
local Combat = require("models.combat")
local AI = require("models.ai")
local Item = require("models.item")
local Fixture = require("tests.support.fixture")

-- One adventurer of `class` (its first leaning race) on the enemy side, one party body `gap` tiles off.
local function field(class, gap)
    local hero = Fixture.walker(3 + gap, 5)
    local spawn = Fixture.unit(Adventurers.variantId(class, Adventurers.leaningRaces(class)[1]), 3, 5)
    local c = Fixture.combat(Fixture.new(12, 9), hero, spawn)
    for _, u in ipairs(c.units) do
        if u.char == spawn.char then
            Fixture.openTurn(c, u)
            return c, u
        end
    end
end

local function planned(c, u)
    local plan = AI.plan(c, u)
    return plan and plan.item and plan.item.id, plan
end

return {
    { name = "the preview of a self-transform reports the shape it takes", fn = function()
        local c, u = field("druid", 3)
        local item
        for _, it in ipairs(require("models.character").eachItem(u.char)) do
            if it.id == "ability_wild_shape_bear" then item = it end
        end
        assert(item, "the druid is not carrying Wild Shape: Bear")
        local preview = Combat.previewAbility(c, u, item, u.x, u.y)
        assert(preview and preview.mutates, "a Wild Shape still previews as touching nothing")
    end },

    { name = "a druid with a foe closing takes bear shape", fn = function()
        local c, u = field("druid", 3)
        local id, plan = planned(c, u)
        assert(id == "ability_wild_shape_bear", "the druid chose " .. tostring(id) .. ": " .. AI.explain(plan))
    end },

    { name = "a summoner with a foe on the board calls an elemental onto open ground", fn = function()
        local c, u = field("summoner", 5)
        local id, plan = planned(c, u)
        assert(id and id:match("^ability_summon_%a+_elemental$"),
            "the summoner chose " .. tostring(id) .. ": " .. AI.explain(plan))
        assert(Combat.unitAt(c, plan.tx, plan.ty) == nil, "the elemental was aimed at an occupied tile")
    end },

    { name = "a trapper with a foe closing sets jaws beside it", fn = function()
        local c, u = field("trapper", 4)
        local id, plan = planned(c, u)
        assert(id == "ability_bear_trap", "the trapper chose " .. tostring(id) .. ": " .. AI.explain(plan))
        local foe = c.units[1]
        assert(math.abs(plan.tx - foe.x) + math.abs(plan.ty - foe.y) == 1,
            "the trap was not set on a square beside the foe")
    end },

    { name = "a body that only carries a plant, with no rule naming it, never lays it", fn = function()
        -- The generic mage carries a fire elemental and no rule for it: offered the turn, it does not call.
        local hero = Fixture.walker(8, 5)
        local spawn = Fixture.unit("character_mage", 3, 5)
        local c = Fixture.combat(Fixture.new(12, 9), hero, spawn)
        for _, u in ipairs(c.units) do
            if u.char == spawn.char then
                Fixture.openTurn(c, u)
                local id = planned(c, u)
                assert(not (id and id:match("^ability_summon_")), "the generic mage summoned unasked: " .. tostring(id))
            end
        end
    end },

    { name = "every benched plant now names where it is aimed and that it plants", fn = function()
        for _, id in ipairs({ "ability_bear_trap", "ability_blast_charge", "ability_snare_stake",
            "ability_spike_trap", "ability_the_floor_gives_way", "ability_summon_fire_elemental",
            "ability_summon_earth_elemental", "ability_summon_ice_elemental",
            "ability_summon_lightning_elemental", "ability_summon_water_elemental",
            "ability_summon_wind_elemental", "ability_summon_golem", "ability_summon_homunculus",
            "ability_summon_wolf", "ability_bind_spirit", "ability_let_it_walk", "ability_field_assembly",
            "ability_faceless_retinue" }) do
            local ab = Item.defs[id] and Item.defs[id].activeAbility
            assert(ab and type(ab.aiAims) == "function" and ab.aiPlants == true, id .. " is still unaimed")
        end
    end },
}
