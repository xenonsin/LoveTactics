-- Through the Grain: the Hamadryad takes a foe that is standing beside her grove and puts it out beside
-- a different plant, wherever strands it farthest from its own company.
--
-- THE ANSWER TO THE ROOFLESS ROOM. The Lust circle's standing counterplay is to choose where the fight
-- happens -- plant yourselves in open ground and most of the circle's shoves have nothing to throw you
-- into. This does not shove. It moves a body through the grove (models/grove.lua) and sets it down alone,
-- which is the company coming apart without anybody being thrown anywhere.
--
-- It needs a plant beside the target and a free tile beside another plant within five, so her grove is
-- the reach: cut the saplings and the hedges and this has nowhere to put anybody. A rooted body cannot be
-- taken -- nothing roots in her fights, but a company's own Root still answers it. A natural weapon: no
-- class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "The Grain Remembers", -- not the spell's name (ability_through_the_grain): see weapon_mistlight
    description = "Moves a foe standing beside a plant out beside another, as far from its allies as it can.",
    flavor = "The wood remembers every shape that has ever stood against it. It can put you back in any of them.",
    sprite = "assets/items/through_the_grain.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        speed = 6,
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(3, 13),
        ai = {
            { priority = "high", act = "cast", targetPref = "nearest",
              when = { subject = "any_foe", test = "within", value = 5 } },
        },
        effect = function(fx)
            local Grove = require("models.grove")
            local t, combat = fx.target, fx.combat
            local dealt = fx.damage(t)
            if dealt <= 0 or not t.alive then return end
            if not Grove.besidePlant(combat, t.x, t.y) then
                fx.log("action", string.format("%s is standing on nothing the grain runs through.", t.char.name or "The target"))
                return
            end
            local Status = require("models.status")
            if Status.blocksForcedMove(t) then
                fx.log("status", string.format("%s is held, and the grain lets go of it.", t.char.name or "The target"))
                return
            end
            local exits = {}
            for _, e in ipairs(Grove.exits(combat, nil, t.x, t.y, 5)) do
                if math.max(math.abs(e.x - t.x), math.abs(e.y - t.y)) > 1 then exits[#exits + 1] = e end
            end
            local best = Grove.farthestFrom(combat, exits, function(u) return u ~= t and u.side == t.side end)
            if best then fx.teleport(t, best.x, best.y) end
        end,
    },
}
