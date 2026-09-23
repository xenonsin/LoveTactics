-- Through the Grain: take a foe standing beside one of your plants and put it out beside a different
-- plant of yours within five tiles, wherever strands it farthest from its own side.
--
-- The Hamadryad's spell, and the one piece of the druid's growing kit that moves a body without shoving
-- it -- so it works on what a shove cannot reach (a body with nothing behind it) and fails on exactly
-- what a shove fails on (Root holds it). It needs the grove on both ends: a plant beside the target, and
-- a free tile beside another plant of yours. Seedfall is what makes the second one.
local Curve = require("models.curve")

return {
    name = "Through the Grain",
    description = "Moves a foe beside one of your plants out beside another, as far from its allies as it can.",
    flavor = "The wood remembers every shape that ever stood against it.",
    sprite = "assets/items/ability_through_the_grain.png",
    type = "ability",
    tags = { "nature", "magical" },
    class = "druid",
    price = 430,
    unlockLevel = 8,
    activeAbility = {
        target = "enemy",
        range = 5,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(11, 21),
        effect = function(fx)
            local Grove = require("models.grove")
            local Status = require("models.status")
            local t, combat, side = fx.target, fx.combat, fx.user.side
            local dealt = fx.damage(t)
            if dealt <= 0 or not t.alive then return end
            if not Grove.besidePlant(combat, t.x, t.y, side) then
                fx.log("action", string.format("%s is standing on nothing of yours the grain runs through.", t.char.name or "The target"))
                return
            end
            if Status.blocksForcedMove(t) then
                fx.log("status", string.format("%s is held, and the grain lets go of it.", t.char.name or "The target"))
                return
            end
            local exits = {}
            for _, e in ipairs(Grove.exits(combat, side, t.x, t.y, 5)) do
                if math.max(math.abs(e.x - t.x), math.abs(e.y - t.y)) > 1 then exits[#exits + 1] = e end
            end
            local best = Grove.farthestFrom(combat, exits, function(u) return u ~= t and u.side == t.side end)
            if best then fx.teleport(t, best.x, best.y) end
        end,
    },
}
