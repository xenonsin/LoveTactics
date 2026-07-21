-- Blizzard: a howling storm of ice over a 3x3 area. Everything caught in it -- friend and foe alike,
-- so mind your own line -- takes ice damage and is left Frozen (data/status/freeze.lua): delayed, and
-- brittle to crush and fire. The area counterpart to Ice Bolt; a ground-target cast (target = "tile",
-- allowOccupied) so you may center it on a clustered enemy.
return {
    name = "Blizzard",
    description = "Deals ice damage and inflicts Frozen on everyone in the area, friend and foe.",
    flavor = "A storm does not check whose line it is falling on. Neither does the mage who called it.",
    sprite = "assets/items/ability_blizzard.png",
    type = "ability",
    tags = { "ice", "magical" },
    class = "mage",
    price = 380,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- an area cast may center on an occupied tile
        range = 3,
        speed = 5,
        channel = 6, -- a longer tell than Fireball, fitting the Freeze payoff
        cost = { stat = "mana", amount = 16 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, -- per-target damage = power + the caster's MagicDamage, minus MagicDefense
        aoe = { radius = 1, shape = "square" }, -- 3x3 storm, corners included
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
                fx.applyStatus(u, "status_freeze", { magnitude = fx.amount })
            end
        end,
    },
}
