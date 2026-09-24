    -- THE CINDER SLIME: Wrath's slime (floors 7-8, the volcanic pit). Each circle's slime line carries one
-- rule of its own; this one's is BOIL OVER (data/traits/trait_boil_over.lua) -- every hit it takes charges
-- it, and at five it erupts in the element it has taken in. Proof against steel like the fen's slime.
    return {
        name = "Cinder Slime",
        race = "beast",
        tier = 2,
        sprite = "assets/chars/cinder_slime.png",
        stats = {
            health = 44, mana = 0, stamina = 16,
            staminaRegen = 2,
            damage = 12, magicDamage = 0,
            defense = 2, magicDefense = 2,
            movement = 3,
            speed = 4,
            skill = 4, luck = 2,
        },
        resist = { fire = 3, water = -3 },
        startingItems = {
            false,              false,              false,
        "weapon_pseudopod", "utility_cinder_body", false,
        false,              false,              false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_seething_core" },
        archetype = "aggressive",
    }
