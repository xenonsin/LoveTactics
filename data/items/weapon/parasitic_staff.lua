return {
    name = "Parasitic Staff",
    description = "A hungry staff that siphons life into arcane power -- restores mana on hit.",
    sprite = "assets/items/parasitic_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" }, -- magical: routes through magicDamage / magicDefense; strikes at melee range
    activeAbility = {
        target = "enemy",
        range = 1, -- adjacent only (Manhattan distance)
        speed = 4, -- time cost: feeds initiative + pushes the actor back
        cost = { stat = "stamina", amount = 6 }, -- spends the renewable resource...
        damage = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 }, -- damage = power + the wielder's Magic Damage, minus Magic Defense
        effect = function(fx)
            fx.damage(fx.target)          -- magicDamage-scaled hit
            fx.restore(fx.user, "mana", 5) -- ...to refill the scarce one
        end,
    },
}
