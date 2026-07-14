-- Drain Mana: siphon a foe's mana into the caster's own reserves. Takes up to fx.amount from the
-- target's mana (Combat.drainResource, which reports what it actually removed) and restores exactly
-- that much to the caster -- a foe with an empty pool yields nothing. `restore` is the leveled
-- magnitude field (fx.amount), so the siphon grows as the item is forged.
return {
    name = "Drain Mana",
    description = "Siphon a foe's mana into your own reserves.",
    sprite = "assets/items/ability_drain_mana.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    price = 180,
    repRank = 2,
    activeAbility = {
        name = "Drain Mana",
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 4 },
        restore = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 20 }, -- fx.amount: the mana siphoned
        effect = function(fx)
            local taken = fx.drain(fx.target, "mana", fx.amount)
            fx.restore(fx.user, "mana", taken)
        end,
    },
}
