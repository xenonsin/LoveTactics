-- Shadow Step: slip through the dark to a foe's side and cut it. The caster blinks to an open tile
-- beside the target (Combat.openTileNear, springing whatever waits there) and strikes. If the target
-- is hemmed in with no open neighbour, the strike still lands from where the caster stood.
--
-- Where it puts you is half of what the cast is weighed on, so it previews: the dry run records the
-- landing (Combat.previewAbility's userRestsX/userRestsY -- fx.teleportUser is inert but no longer
-- silent), the board rings that tile while the blink is aimed, and the counter preview weighs the
-- blow from it rather than from the tile four squares back that it is nominally thrown from.
local Curve = require("models.curve")

return {
    name = "Shadow Step",
    description = "Blinks to a foe's side and strikes it.",
    flavor = "The Undercroft's preferred introduction.",
    sprite = "assets/items/ability_shadow_step.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    price = 260,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 4,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(8, 18),
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local x, y = fx.openTileNear(t.x, t.y)
            if x then fx.teleportUser(x, y) end
            fx.damage(t)
        end,
    },
}
