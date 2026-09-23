-- Heartwood: plant a sapling and put your life in it -- once.
--
-- The Hamadryad's bond, carried out of the Churchyard Yew at a fraction of its strength. Hers holds for
-- as long as her tree stands; this holds for ONE killing blow: while the sapling you planted lives, the
-- blow leaves you at 1 health and sets you down beside it, and the bond is spent
-- (data/status/status_heartbound.lua, `magnitude = 1`). A sapling is a small body that can be cut down,
-- so the enemy's answer is to go and cut it -- which is a turn it is not spending on you.
--
-- Found in the rift and dealt at the druid counter once the class has grown that far. Unpriced, as every
-- utility above a house's opener is.
return {
    name = "Heartwood",
    description = "Plants a sapling beside you. While it stands, the next killing blow leaves you at 1, beside it.",
    flavor = "She is the part of the tree that learned to walk away from it. You are borrowing the trick, not the tree.",
    sprite = "assets/items/utility_heartwood.png",
    type = "utility",
    tags = { "nature" },
    class = "druid",
    unlockLevel = 15,
    activeAbility = {
        target = "self",
        support = true,
        range = 0,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            local x, y = fx.openTileNear(fx.user.x, fx.user.y)
            if not x then
                fx.log("action", "There is no ground beside you to plant in.")
                return
            end
            local sapling = fx.summon("character_sapling", x, y, { control = "none", timeless = true })
            if sapling and sapling.alive then
                fx.applyStatus(fx.user, "status_heartbound", { magnitude = 1, applier = sapling })
            end
        end,
    },
}
