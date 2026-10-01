-- THE DECREE: the Throne's whole attack (reviewed 2026-09-30, "Pride's Bestiary"). It does not aim at anyone.
-- It lights a pattern of the floor around its body -- the cross, then the rings, then the lines, in turn -- and
-- the light lands, holy, when its slot comes back round (models/choir.lua).
--
-- IT IS A WIND-UP, AND THAT IS THE WHOLE TELEGRAPH. The board already paints every enemy wind-up's tiles in the
-- pulsing detonation colour (ui/battle_map.lua's channelAoe), so the lit pattern is drawn by machinery the player
-- has learned on every Meteor Storm in the game; `aoe.cells` returns the pattern, and the ordinary resolution is
-- the strike. Five ticks is one turn: every body on the board gets about one move to read the floor and step off
-- it. Only foes are struck -- the choir stands in its own light.
--
-- Incorruptible keeps it whole: the two things that break a wind-up are hard control and being moved, and
-- neither lands on an angel. What stops a decree is ending the Throne, or not standing in it.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "The Decree",
    description = "Lights a pattern of tiles around the body. Next turn, every foe in it takes holy damage.",
    flavor = "It is not a judgement. A judgement implies the matter was ever in doubt.",
    sprite = "assets/items/weapon_the_decree.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "holy", "magical" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = false, -- a self-cast that strikes: the lit tiles paint as a threat
        range = 0,
        speed = 2,
        windup = 5, -- one turn: the pattern hangs for exactly the beat a body needs to step out of it
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(10, 20),
        aoe = {
            cells = function(combat, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                return require("models.choir").decreeCells(combat, unit)
            end,
        },
        effect = function(fx)
            require("models.choir").strike(fx)
        end,
    },
}
