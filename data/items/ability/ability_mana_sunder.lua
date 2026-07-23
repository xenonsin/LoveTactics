-- Mana Sunder: the knight half of the Spellbreaker. A strike that burns a caster's mana to nothing
-- (fx.drain -- taken, not stolen) AND Silences it: not a momentary interrupt but a hard lockout, the
-- pool gone and the casting sealed both. Sloth's answer to pride -- it does not out-cast the mage, it
-- takes casting away.
return {
    name = "Mana Sunder",
    description = "Strikes a foe, burns its mana away, and Silences it: no mana, and no casting either.",
    flavor = "Not the spell. The saying of spells.",
    sprite = "assets/items/ability_mana_sunder.png",
    type = "ability",
    tags = { "impact", "physical" },
    class = "knight",
    discipline = "spellbreaker", -- knight x mage; the Counterspell mechanic's first stock
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        damage = { 5, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14 },
        restore = { 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30 }, -- fx.amount: the mana burned off
        effect = function(fx)
            fx.damage(fx.target)
            fx.drain(fx.target, "mana", fx.amount) -- burned, not siphoned: the Spellbreaker keeps nothing
            fx.applyStatus(fx.target, "status_silenced")
        end,
    },
}
