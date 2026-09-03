-- A rime-gnat's nip: it costs a turn rather than health.
--
-- The Sloth swarm's whole worth is the Freeze it leaves. On the one board where crossing is free
-- (data/biomes/tundra.lua), what a circle has to charge for is the clock -- and this is that charge at
-- the cheapest rung available. Three gnats and somebody has lost a turn.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Rime Nip",
    description = "Nips an adjacent foe and leaves Freeze.",
    flavor = "Not cold enough to kill. Cold enough to be late.",
    sprite = "assets/items/rime_nip.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "ice", "magical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 3 },
        damage = Curve.ramp(2, 12),
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_freeze")
        end,
    },
}
