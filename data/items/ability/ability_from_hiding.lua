-- FROM HIDING: the Bugbear's ambush (approved as pitched, 2026-09-26, "The Goblins of Wrath"). It starts the
-- fight Invisible on a flank (its Ambusher's Hood), and a blow struck on a turn it opened unseen
-- (Combat.unseenFor) deals double damage and Stuns. Seen, it is only a heavy club. A body's own, never shelved:
-- the drop is the hood.
local Curve = require("models.curve")

return {
    name = "From Hiding",
    description = "Strikes an adjacent foe. Opened unseen, deals double damage and Stuns.",
    flavor = "Big enough to be seen from across a room. Nobody ever looks at that part of the room.",
    sprite = "assets/items/ability_from_hiding.png",
    type = "ability",
    tags = { "impact", "physical", "melee" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(10, 22),
        effect = function(fx)
            local target = fx.target
            if not (target and target.alive) then return end
            if require("models.combat").unseenFor(fx.combat, fx.user) then
                fx.damage(target, { amount = (fx.amount or 0) * 2 })
                fx.applyStatus(target, "status_stun")
            else
                fx.damage(target)
            end
        end,
    },
}
