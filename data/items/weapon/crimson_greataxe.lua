-- Colosseum rank-4. The axe drinks what it spills: heavy, slow, and it hits harder the deeper
-- the fight goes. The Colosseum's masters do not say where the crimson comes from -- the first
-- hint that the arena's patron sin is Wrath, and that Wrath grows on damage taken.
return {
    name = "Crimson Greataxe",
    description = "A greataxe slick with a red that never dries. Devastating, and slow to swing.",
    sprite = "assets/items/crimson_greataxe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical" },
    class = "fighter",
    price = 800,
    repRank = 4,
    activeAbility = {
        name = "Cleave",
        target = "enemy",
        range = 1,
        speed = 6, -- ponderous: you pay for the damage in turn order
        cost = { stat = "stamina", amount = 16 },
        power = 18,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
