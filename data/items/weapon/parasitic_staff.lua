return {
    name = "Parasitic Staff",
    description = "A hungry staff that siphons life into arcane power -- restores mana on hit.",
    sprite = "assets/items/parasitic_staff.png",
    type = "weapon",
    tags = { "staff", "magical", "melee" }, -- magical: routes through magicDamage / magicDefense; strikes at melee range
    -- Every staff swaps Wait into Focus (docs/weapons.md). This one is the family taken further: it
    -- also siphons mana on the HIT below, so it can refill while still attacking -- Focus is its floor,
    -- not its only recourse. It focuses deeper than a plain staff, befitting the rarer weapon.
    waitBehavior = { kind = "focus", mana = { 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 }, speed = 10 },
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
