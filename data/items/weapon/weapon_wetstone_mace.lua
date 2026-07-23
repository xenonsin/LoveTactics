-- A mace, so it shoves (docs/weapons.md). Two extras, and they are the same one: the head is charged, so
-- the blow lands `lightning`-tagged, and the shove leaves the target Wet (status_wet) -- which is +6
-- taken from every lightning hit thereafter, including this mace's own next swing.
--
-- The only self-comboing weapon on the knight's shelf. Swing one, the foe is soaked; swing again and the
-- second blow is worth six more than the first. Nothing has to be coordinated with anybody, which is
-- unusual for a setup weapon and is what earns it a mid rank rather than a high one -- the payoff is
-- real but it is small, and it takes two turns to arrive.
--
-- The wider chain is where it gets interesting: Wet is also +6 from ice and -6 against fire, so a soaked
-- rank is a gift to the Arcanum and a problem for anyone carrying a torch. Read it beside
-- data/items/weapon/weapon_tidesbreak.lua (soaks a whole line and does nothing with it) and
-- data/items/weapon/weapon_conductor.lua (soaks nobody and harvests everything already soaked) -- three
-- shelves, one combo, and this is the one that can run it alone.
return {
    name = "Wetstone Mace",
    description = "Soaks the target and drives them back two tiles -- and the charged head bites deeper on anything already wet.",
    flavor = "The quenching trough is not for cooling it. Nobody at the forge has ever been able to explain what it is for.",
    sprite = "assets/items/wetstone_mace.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "lightning", "melee" },
    class = "knight",
    price = 360,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 9 },
        -- Under an iron mace's: the second swing is where this weapon's number actually lives.
        damage = { 6, 7, 8, 8, 9, 10, 11, 11, 12, 13, 14 },
        effect = function(fx)
            -- Soak FIRST, then strike. A mace that hit and then wet would never benefit from its own
            -- vulnerability on the opening blow, and the ordering is free -- the shove rides in the
            -- damage call below, so the whole thing is still one blow as far as the timeline is concerned.
            fx.applyStatus(fx.target, "status_wet")
            fx.damage(fx.target, { knockback = { distance = 2, amount = fx.amount } })
        end,
    },
}
