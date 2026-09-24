    -- THE GLACIER KING: all three Sloth slimes in one -- an elite on Sloth's seat floor. Its blows push your
-- turn back twice as far and Numb you, it grows while it holds still, and it divides into one of each.
    --
    -- `boss = true` for the King Slime's reasons (Coup de Grace must not skip the split), and fielded
    -- under `killAll` -- never an `assassinate` mark.
    return {
        name = "Glacier King",
        race = "beast",
        tier = 4,
        boss = true,
        sprite = "assets/chars/glacier_king.png",
        stats = {
            health = 165, mana = 0, stamina = 24,
            staminaRegen = 2,
            damage = 16, magicDamage = 0,
            defense = 3, magicDefense = 3,
            movement = 3,
            speed = 4,
            skill = 6, luck = 2,
        },
        resist = { ice = 5, fire = -5 },
        startingItems = {
            false,              false,             false,
            "weapon_pseudopod", "utility_glacier_heart", false,
            false,              false,             false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_the_slow_hour", "utility_stillwater", "utility_heavy_lids", "utility_deep_sleep", "utility_snowslide", "utility_patient_blade" },
        archetype = "aggressive",
    }
