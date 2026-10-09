-- THE RIFT'S ADVENTURERS, SLICE B (2026-10-09): fourteen race-free adventurer bodies -- the subclasses
-- and crossings from the Barbarian to the Poacher. Each case holds a promise the slice made about every
-- body: it wears any race, it fields with a basic action it can use, and its own rules pick a turn on a
-- bare board. The party contract itself is tests/adventurers_spec.lua's.

local Adventurers = require("models.adventurers")
local Character = require("models.character")
local Combat = require("models.combat")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local CLASSES = {
    "barbarian", "sentinel", "assassin", "druid", "necromancer", "monk", "poisoner",
    "crusader", "mammonite", "summoner", "trapper", "apothecary", "champion", "poacher",
}

-- The leaning race, and one race that does not lean to the class.
local function races(class)
    local lean = Adventurers.leaningRaces(class)
    local leans = {}
    for _, r in ipairs(lean) do leans[r] = true end
    for _, r in ipairs(Adventurers.RACES) do
        if not leans[r] then return lean[1], r end
    end
end

-- One adventurer on the enemy side and one party body three tiles off, wounded to `frac` of its health.
local function field(id, frac)
    local hero = Fixture.walker(6, 5)
    local hp = hero.char.stats.health
    hp.current = math.floor(hp.max * (frac or 1))
    local spawn = Fixture.unit(id, 3, 5)
    local c = Fixture.combat(Fixture.new(9, 9), hero, spawn)
    for _, u in ipairs(c.units) do
        if u.char == spawn.char then return c, u end
    end
end

return {
    { name = "every slice-B body instantiates as its leaning race and as another", fn = function()
        for _, class in ipairs(CLASSES) do
            local base = rawget(Character.defs, Adventurers.bodyOf(class))
            assert(base, "no body for " .. class)
            assert(base.race == Adventurers.leaningRaces(class)[1], class .. " should load as its first leaning race")
            for _, race in ipairs({ races(class) }) do
                local id = Adventurers.variantId(class, race)
                local char = Character.instantiate(id)
                assert(char.race == race, id .. " lost its race")
                assert(char.discipline == class or base.discipline == class, id .. " walks the wrong class")
            end
        end
    end },

    { name = "every slice-B body fields with a basic action it can use", fn = function()
        for _, class in ipairs(CLASSES) do
            local lean, other = races(class)
            for _, race in ipairs({ lean, other }) do
                local id = Adventurers.variantId(class, race)
                local c, u = field(id)
                local action = Combat.defaultAction(u.char, u)
                assert(action, id .. " fields with no default action")
                Fixture.openTurn(c, u)
                assert(not Combat.itemBlockReason(u, action), id .. " cannot use its default action "
                    .. tostring(action.id))
            end
        end
    end },

    { name = "every slice-B body's rules pick a turn on a bare board", fn = function()
        for _, class in ipairs(CLASSES) do
            local id = Adventurers.variantId(class, (races(class)))
            -- Wounded under a quarter, so the finishers (the Assassin, the Monk) have a body to act on.
            local c, u = field(id, 0.2)
            Fixture.openTurn(c, u)
            local plan = AI.plan(c, u)
            assert(plan and (plan.item or plan.move), id .. " did nothing: " .. AI.explain(plan))
        end
    end },

    { name = "the combos the party pages name are what the bodies choose", fn = function()
        -- Each: { body, who is hurt and how far, the item its turn should reach for }.
        local CASES = {
            { "barbarian", "self", 0.3, "ability_fury" },
            { "sentinel", "mate", 0.5, "ability_shared_burden" },
            { "assassin", "foe", 0.2, "ability_coup_de_grace" },
            { "champion", "foe", 1, "ability_provoke" },
            { "poacher", "foe", 1, "ability_bolas" },
            { "apothecary", "mate", 0.5, "ability_heal" },
        }
        for _, case in ipairs(CASES) do
            local class, who, frac, want = case[1], case[2], case[3], case[4]
            local hero = Fixture.walker(6, 5)
            local spawn = Fixture.unit(Adventurers.variantId(class, (races(class))), 3, 5)
            local mate = Fixture.unit("character_adv_barbarian@human", 3, 6)
            local c = Fixture.combat(Fixture.new(9, 9), hero, { spawn, mate })
            local units = {}
            for _, u in ipairs(c.units) do
                if u.char == spawn.char then units.self = u
                elseif u.char == mate.char then units.mate = u
                else units.foe = u end
            end
            local hp = units[who].char.stats.health
            hp.current = math.floor(hp.max * frac)
            Fixture.openTurn(c, units.self)
            local plan = AI.plan(c, units.self)
            assert(plan and plan.item and plan.item.id == want, class .. " should reach for " .. want .. ": "
                .. AI.explain(plan))
        end
    end },

    { name = "the Necromancer raises a fallen ally and bursts a fallen foe", fn = function()
        for _, which in ipairs({ "ability_raise_dead", "ability_corpse_burst" }) do
            local near, far = Fixture.walker(7, 5), Fixture.walker(7, 6)
            local spawn = Fixture.unit("character_adv_necromancer@human", 3, 5)
            local mate = Fixture.unit("character_adv_barbarian@human", 4, 6)
            local fodder = Fixture.unit("character_adv_monk@human", 4, 7)
            local c = Fixture.combat(Fixture.new(10, 10), { near, far }, { spawn, mate, fodder })
            local me, body
            for _, u in ipairs(c.units) do
                if u.char == spawn.char then me = u end
                if (which == "ability_raise_dead" and u.char == fodder.char)
                    or (which == "ability_corpse_burst" and u.char == far.char) then body = u end
            end
            -- Laid down as a corpse outright: the revive window between the two states is not this case.
            Combat.dealFlatDamage(c, body, 9999, { "physical" }, "test", nil, { raw = true })
            body.alive, body.corpse = false, true
            Fixture.openTurn(c, me)
            local plan = AI.plan(c, me)
            assert(plan and plan.item and plan.item.id == which, "the necromancer should " .. which .. ": "
                .. AI.explain(plan))
        end
    end },

    { name = "the Assassin stands idle while nobody is under half", fn = function()
        local c, u = field(Adventurers.variantId("assassin", "oni"), 1)
        Fixture.openTurn(c, u)
        local plan = AI.plan(c, u)
        assert(plan and plan.wait, "he moved on a whole body: " .. AI.explain(plan))
    end },
}
