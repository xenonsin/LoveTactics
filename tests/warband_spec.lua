-- Tests for models/warband.lua -- the enemy company drawn as a combo rather than listed as a roster.
--
-- WHAT THIS FILE IS FOR, and it did not exist until the draw learned about depth. A warband is the one
-- thing that appears on EVERY floor: the circles are locked to their own ground, so the company you
-- meet is what keeps a floor from being empty at any depth. That makes two questions load-bearing and
-- neither had a case -- whether the bodies in it are ones the floor could account for, and whether the
-- combo still assembles once they are filtered.

local Warband = require("models.warband")
local Class = require("models.class")
local Character = require("models.character")

return {
    {
        -- NO ASSASSIN ON FLOOR ONE. Drawn flat, all thirty-six bodies were legal on the first board --
        -- including disciplines a player cannot reach for another five, nine or fifteen rungs. The gate
        -- is Class.gateLevel, on the same 0..CLASS_LEVEL_CAP ladder the floor count runs on, and the
        -- drop pool has read it since a Warden charm fell out of floor one eight rungs early
        -- (Spoils.depthOf). This is that reading, one system over.
        name = "a company is drawn only from disciplines the floor could have produced",
        fn = function()
            -- Pinned to the ladder rather than to a list of names: if a discipline's gate moves, this
            -- says so instead of quietly testing a rung nobody uses.
            local deepest = { assassin = 5, warden = 15, saboteur = 14, spellbreaker = 13 }
            for id, rung in pairs(deepest) do
                local key = "character_" .. id
                local def = Character.defs[key]
                assert(def, key .. " is not a blueprint")
                assert(Class.gateLevel(def.discipline) == rung, string.format(
                    "%s asks for rung %d, not the %d this case is pinned to",
                    id, Class.gateLevel(def.discipline), rung))
                assert(not Warband.legal(key, rung - 1), id .. " is legal a rung above its gate")
                assert(Warband.legal(key, rung), id .. " is refused on the floor that opens it")
            end

            -- A caller that cannot say how deep it is gets everything. models/muster.lua rates
            -- compositions long before a board exists, and a rating is not a placement.
            assert(Warband.legal("character_warden", nil), "a floorless caller is gated")
        end,
    },

    {
        -- The property, over every depth rather than over the four names above.
        name = "no company fields a body its floor has not opened",
        fn = function()
            local Descent = require("models.descent")
            for floor = 1, Descent.FLOORS do
                local ctx = { day = 20, quest = { descent = { seed = 4242, floor = floor } } }
                local ids = Warband.compose(ctx)
                assert(#ids >= 4, string.format(
                    "floor %d composed a %d-body company -- the four roles are the shape",
                    floor, #ids))
                for _, id in ipairs(ids) do
                    local def = Character.defs[id]
                    assert(def, "floor " .. floor .. " fielded " .. id .. ", which is not a blueprint")
                    local gate = Class.gateLevel(def.discipline or def.class)
                    assert(gate <= floor, string.format(
                        "floor %d fielded %s, whose discipline asks for rung %d", floor, id, gate))
                end
            end
        end,
    },

    {
        -- THE HALF THE GATE CANNOT DELIVER ON ITS OWN, and the reason the root exemplars are in the
        -- buckets. Every body the buckets held was a DISCIPLINE and the cheapest asks for rung 3, so
        -- reading the gate honestly left floors one and two with four legal bodies between them --
        -- three of them anchors. A company of four identical knights is not a sentence, and those two
        -- boards are where a player learns to read one.
        name = "the shallow floors still assemble a company worth reading",
        fn = function()
            for floor = 1, 2 do
                local ctx = { day = 20, quest = { descent = { seed = 4242, floor = floor } } }
                local ids = Warband.compose(ctx)
                local distinct, n = {}, 0
                for _, id in ipairs(ids) do
                    if not distinct[id] then distinct[id] = true; n = n + 1 end
                end
                assert(n >= 3, string.format(
                    "floor %d's company is %d distinct bodies -- the combo has nothing to be about",
                    floor, n))
            end
        end,
    },

    {
        -- The draw is a pure function of the seed and the depth, which is what a resumed floor rests
        -- on: the same run meets the same company after a save and reload, on any machine.
        name = "the same floor of the same run composes the same company",
        fn = function()
            local function at(seed, floor)
                return table.concat(
                    Warband.compose({ day = 20, quest = { descent = { seed = seed, floor = floor } } }), ",")
            end
            assert(at(11, 6) == at(11, 6), "the same floor drew two different companies")
            assert(at(11, 6) ~= at(12, 6) or at(11, 7) ~= at(12, 7),
                "the seed does not reach the draw -- every run would meet the same companies")
        end,
    },
}
