-- Hunter's Lodge rank-4. Strung with sinew from something the Lodge will not name. Outranges every
-- other bow and needs a clear arc, like all of them.
--
-- The Lodge sells the trophies of sacred beasts and eats the rest. Nobody there asks what happens
-- to a hunter who never stops being hungry -- the first hint of Gluttony.
return {
    name = "Hornbow of the Hunt",
    description = "A great hornbow that reaches across the field. Cannot fire at point-blank range.",
    sprite = "assets/items/hornbow_of_the_hunt.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    class = "hunter",
    price = 800,
    repRank = 4,
    activeAbility = {
        name = "Longshot",
        target = "enemy",
        range = 5, -- two tiles further than a plain bow
        minRange = 2,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 10 },
        power = 14,
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
