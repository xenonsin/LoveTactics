-- THE PALE CRONE: Envy's own likeness, on the Ribstone Waste's approach ("Envy's Bestiary", round 4, 2026-10-06).
-- Ovid's Envy (Metamorphoses II) walks with a staff wound in thorns and wastes at the sight of another's success.
-- She leads the Wasting Ones.
--
--   GRIEF AT YOUR FORTUNE   when a body of the company is healed or blessed where she can see it, she leaps beside
--                           it at once and strikes, out of turn, once a round (trait_grief_at_fortune;
--                           models/envy_oneoffs.lua)
--
--                           AND AT YOUR KILLS (creature identity pass, 2026-11-19): a foe in her sight that
--                           fells a body is leapt on the same way. Success is not only a priest's: every company
--                           kills, so she now reads every company (the same-envy-support row).
--
-- THE COUNTERPLAY, STATED, and it is the review's own: heal behind a ridge, or bait the leap -- bless a body
-- standing where she will land in the open, among your blades. And take your kills out of her sight, or with the
-- body you want her to land beside.
--
-- TARGETING: her leap is her targeting -- she goes to whoever prospered, out of turn -- so her own turn is left to
-- the ordinary planner.
--
-- NOT THE KINSLAYER, though both read heals and blessings: he hunts the favoured body across a fight, and she
-- answers each one with a single leap. A demon, so her staff burns and she takes holy the harder.
return {
    name = "The Pale Crone",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/pale_crone.png",
    stats = {
        health = 96, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 13, magicDamage = 0,
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 6, luck = 4,
    },
    -- Old and dry as the waste: a point goes through to nothing, and fire is what she is made of.
    resist = { pierce = 2, impact = -2 },
    startingItems = {
        "weapon_withering_staff", "utility_grief_at_fortune", false,
        false,                    false,                      false,
        false,                    false,                      false,
    },
    drops = { "utility_thorned_staff" },
    defaultAction = "weapon_withering_staff",
    archetype = "aggressive",
}
