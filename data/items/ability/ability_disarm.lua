-- Disarm: a splash of solvent that fouls a foe's grip so it cannot use its weapon for a time
-- (data/status/disarmed.lua). Pure control -- it deals no damage; the payload is the Disarmed status,
-- which strikes the blade from the hand (Combat.itemBlockReason refuses any crafted weapon, basic
-- attack included) while leaving abilities, potions, and a bare-fisted punch untouched. Aim it at the
-- thing that lives by its weapon: a heavy hitter drops to slapping for a few turns.
return {
    name = "Disarm",
    description = "Inflicts Disarmed: the foe cannot use its weapon for a time. Deals no damage.",
    flavor = "A splash of solvent -- the Crucible's answer to anything that lives by its grip.",
    sprite = "assets/items/ability_disarm.png",
    type = "ability",
    tags = { "arcane" },
    class = "alchemist",
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_disarmed")
        end,
    },
}
