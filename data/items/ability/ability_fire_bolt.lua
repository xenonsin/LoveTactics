-- Fire Bolt: a single darting flame that scorches one foe and leaves it Burning (data/status/burn.lua),
-- searing it for a few turns after. The single-target fire counterpart to the mage's Ice Bolt -- where
-- ice delays, fire lingers. Scales with magic.
return {
    name = "Fire Bolt",
    description = "Sear a foe with flame, leaving it Burning.",
    sprite = "assets/items/ability_fire_bolt.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mage",
    price = 150,
    repRank = 2,
    activeAbility = {
        name = "Fire Bolt",
        target = "enemy",
        range = 3,
        requiresSight = true, -- a bolt needs a clear line: terrain cover blocks it
        speed = 3,
        cost = { stat = "mana", amount = 10 },
        power = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, -- per-hit damage = power + the caster's MagicDamage, minus MagicDefense
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "burn")
        end,
    },
}
