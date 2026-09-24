    -- THE MIMIC SLIME: Envy's slime (floors 11-12, the desert). Both halves of the sin at once -- it becomes
-- the first foe that targets it (trait_mimicry) and gains every blessing its foes gain (trait_begrudge).
-- Proof against steel like the fen's slime.
    return {
        name = "Mimic Slime",
        race = "beast",
        tier = 2,
        sprite = "assets/chars/mimic_slime.png",
        stats = {
            health = 44, mana = 0, stamina = 16,
            staminaRegen = 2,
            damage = 12, magicDamage = 0,
            defense = 2, magicDefense = 2,
            movement = 3,
            speed = 4,
            skill = 4, luck = 2,
        },
        resist = { lightning = 3, water = -3 },
        startingItems = {
            false,              false,              false,
        "weapon_pseudopod", "utility_mimic_body", false,
        false,              false,              false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_copycat" },
        archetype = "aggressive",
    }
