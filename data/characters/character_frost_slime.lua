    -- THE FROST SLIME: one of Sloth's three slimes. Its rule is NUMB (data/traits/trait_numb.lua): its
-- blows make everything you pay for cost more. Sloth takes effort.
    return {
        name = "Frost Slime",
        race = "beast",
        tier = 2,
        sprite = "assets/chars/frost_slime.png",
        stats = {
            health = 44, mana = 0, stamina = 16,
            staminaRegen = 2,
            damage = 12, magicDamage = 0,
            defense = 2, magicDefense = 2,
            movement = 3,
            speed = 4,
            skill = 4, luck = 2,
        },
        resist = { ice = 3, fire = -3 },
        startingItems = {
            false,              false,              false,
        "weapon_pseudopod", "utility_frost_body", false,
        false,              false,              false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_idle_hands" },
        archetype = "aggressive",
    }
