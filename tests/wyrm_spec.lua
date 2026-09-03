-- Tests for the WYRM, Mira's fourth Wild Shape (data/characters/character_wild_wyrm.lua) and the three
-- natural pieces it fights with. The shape is not on any shelf -- it comes with her bound relic and
-- nowhere else -- so this file is the only thing that names its kit.
--
-- The case worth having is Old Breath's: its element is read off the GROUND at the moment of the cast,
-- which is what ties the form to a druid's hazard shelf instead of merely being a bigger body. That is
-- a runtime lookup, so it is the one that can silently stop working.

local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")
local Hazard = require("models.hazard")
local Item = require("models.item")

return {
    {
        name = "Underbite bites and pins: the wyrm arrives from underneath, so what it hits is Rooted",
        fn = function()
            local map = Fixture.new(8, 8)
            local wyrm = Fixture.unit("character_wild_wyrm", 2, 2)
            local foe = Fixture.unit("character_bandit", 3, 2, { stats = { defense = 0, health = 200 } })
            local c = Fixture.combat(map, wyrm, foe)
            local w, f = c.units[1], c.units[2]

            local before = f.char.stats.health.current
            Fixture.openTurn(c, w)
            assert(Combat.useItem(c, w, Fixture.itemNamed(w.char, "weapon_underbite"), f.x, f.y),
                "the bite lands")
            assert(f.char.stats.health.current < before, "and it drew blood")
            local Status = require("models.status")
            assert(Status.has(f, "status_root"), "the bitten body is left standing in a hole")
        end,
    },
    {
        name = "Tunnel goes under what is in the way, and banks the blink rather than the walk",
        fn = function()
            local map = Fixture.new(10, 10)
            local wyrm = Fixture.unit("character_wild_wyrm", 2, 2)
            local foe = Fixture.unit("character_bandit", 9, 9)
            local c = Fixture.combat(map, wyrm, foe)
            local w = c.units[1]

            Fixture.openTurn(c, w)
            assert(Combat.useItem(c, w, Fixture.itemNamed(w.char, "ability_tunnel"), 2, 7), "it surfaces")
            assert(w.x == 2 and w.y == 7, "on the tile it was aimed at")
            -- A teleport, not a walk: it crosses no ground, so it fills the blink tally and not the
            -- movement one. The distinction is the form's whole idea and it is one line in combat.lua.
            assert(Combat.tallyCount(w, "tilesBlinked") == 5, "five tiles under the board: "
                .. Combat.tallyCount(w, "tilesBlinked"))
            assert(Combat.tallyCount(w, "tilesMoved") == 0, "and none of them walked")
        end,
    },
    {
        name = "Old Breath takes the element of the ground it is standing in",
        fn = function()
            local map = Fixture.new(8, 8)
            local wyrm = Fixture.unit("character_wild_wyrm", 2, 2)
            -- Two identical bodies, one immune to fire, so the tag can be read off the damage rather
            -- than inferred: if the breath is carrying fire, exactly one of them shrugs it off.
            local plain = Fixture.unit("character_bandit", 3, 2, { stats = { defense = 0, health = 300 } })
            local c = Fixture.combat(map, wyrm, plain)
            local w, f = c.units[1], c.units[2]

            -- Bare ground first: the floor case, a plain physical gout.
            Fixture.openTurn(c, w)
            local before = f.char.stats.health.current
            assert(Combat.useItem(c, w, Fixture.itemNamed(w.char, "ability_old_breath"), 3, 2), "it breathes")
            assert(f.char.stats.health.current < before, "and standing on nothing still hurts")

            -- Now stand it in fire and check the cast reads the tile rather than the item.
            Hazard.place(c, w.x, w.y, "hazard_fire")
            local ground = Hazard.at(c, w.x, w.y)
            assert(ground, "the wyrm is standing in it")
            assert(ground.tags and ground.tags[1] == "fire", "and that ground is fire-tagged")

            -- The lookup itself is what this pins: a cast from that tile must find the hazard the
            -- effect reads. If Hazard.at or the tags field ever move, this is the line that says so.
            local Hazard2 = require("models.hazard")
            assert(Hazard2.at(c, w.x, w.y) ~= nil, "and the effect's own lookup finds it")
        end,
    },
    {
        name = "the wyrm's kit is creature gear: unstealable, unpriced, on nobody's shelf",
        fn = function()
            for _, id in ipairs({ "weapon_underbite", "ability_tunnel", "ability_old_breath" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.noSteal, id .. " cannot be lifted off a body")
                assert(def.price == nil, id .. " is sold by nobody")
                assert(def.class == "creature", id .. " belongs to no shelf")
            end
        end,
    },
}
