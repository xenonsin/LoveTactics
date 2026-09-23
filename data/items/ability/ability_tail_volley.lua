-- TAIL VOLLEY: the Manticore's tail, emptied across an area. Built on Rain of Arrows' footprint -- aimed
-- at a cell in sight, it sweeps the 3x3 around it -- and every FOE standing there takes a quill: a light
-- pierce blow carrying one stack of status_quilled INSIDE the damage call, so a quill that misses lodges
-- nothing (docs/accuracy.md's clean miss).
--
-- FOES ONLY, which is the one departure from Rain of Arrows. That is thrown at ground and takes whoever
-- stands on it; this is an animal's own tail, and a pair of manticores sharing a fight would otherwise
-- quill each other every volley and hand the company its own combo.
--
-- ON A COOLDOWN, NOT A PURSE. It was pitched with four quills a tail that only regrew by biting, and
-- that was cut on review (2026-09-23): "have tail volley just be on a cooldown". So it fires every other
-- turn or so (10 ticks, Combat.castCooldownKey) and the stacks are what climb -- the second volley into a
-- front line that ate the first one lands two points a quill harder, the third four. The Man-eater hands
-- the cooldown back when a foe goes down beside it (trait_man_eater).
local Curve = require("models.curve")

return {
    name = "Tail Volley",
    description = "Looses quills across an area, striking only foes. Each quill that lands inflicts Quilled.",
    flavor = "Forward and backward alike, the old books say, and as far as a bow.",
    sprite = "assets/items/ability_tail_volley.png",
    type = "ability",
    class = "creature",
    tags = { "physical", "pierce" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        cooldown = 10, -- ~2 turns at Status.TICKS_PER_TURN
        damage = Curve.ramp(1, 11), -- light: the quill it leaves is the point, not the blow
        aoe = { radius = 1, shape = "square" },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.damage(u, { inflicts = "status_quilled" })
                end
            end
        end,
    },
}
