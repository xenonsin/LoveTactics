-- A zombie's natural weapon: slow, clumsy, but strong. What a raised corpse swings (Raise Dead,
-- data/items/ability/ability_raise_dead.lua). `noSteal` -- and pointless to steal besides.
return {
    name = "Rotting Claws",
    description = "Maul an adjacent foe with dead hands.",
    sprite = "assets/items/rotting_claws.png",
    type = "weapon",
    tags = { "natural", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5, -- slow and lurching
        cost = { stat = "stamina", amount = 5 },
        damage = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 13, 14 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
