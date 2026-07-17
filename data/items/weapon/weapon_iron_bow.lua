return {
    name = "Iron Bow",
    description = "Fires an arrow at range. Cannot shoot a foe standing next to you.",
    flavor = "The Lodge's first bow. It teaches distance before it teaches aim.",
    sprite = "assets/items/bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2, -- every bow is two-handed: one hand holds the stave, the other draws (Dual Wield can pair it only once forged to +5)
    class = "hunter",
    price = 80,
    repRank = 1,
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2, -- a bow can't fire at adjacent tiles: no point-blank shots
        requiresSight = true, -- an arrow needs a clear line: terrain cover blocks the shot
        speed = 2, -- lighter/faster than the sword
        cost = { stat = "stamina", amount = 6 },
        damage = { 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
