-- IFRIT'S FLAME: the Ifrit's bolt, a body's own. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- A fire bolt that sets the struck tile alight (hazard_fire, the Emberwand's ember) and leaves its target on a
-- Fire Trail (status_fire_trail): every tile it is pushed or steps through for the next two turns catches fire
-- under it, and it with it. Standing still is the answer -- which the Djinni beside it is there to take away.
--
-- An organ, not the trophy: what an Ifrit gives up is the coal that lights its spells (utility_ifrits_coal).
local Curve = require("models.curve")

return {
    name = "Ifrit's Flame",
    description = "Sets the target's tile alight and inflicts Fire Trail.",
    flavor = "It does not throw the fire. It lends it, and lets you carry it home.",
    sprite = "assets/items/ability_ifrits_flame.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line, as every bolt's does
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.damage(t)
            fx.placeHazard(t.x, t.y, "hazard_fire", { amount = 3 + fx.level, duration = 10 + fx.level })
            if t.alive then fx.applyStatus(t, "status_fire_trail") end
        end,
    },
}
