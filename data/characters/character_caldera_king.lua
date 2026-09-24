    -- THE CALDERA KING: the cinder slime crowned -- an elite on Wrath's seat floor. Erupts at three stacks,
-- and comes apart into three cinder slimes that are already Seething (utility_caldera_heart).
    --
    -- `boss = true` for the King Slime's reasons (Coup de Grace must not skip the split), and fielded
    -- under `killAll` -- never an `assassinate` mark.
    return {
        name = "Caldera King",
        race = "beast",
        tier = 4,
        boss = true,
        sprite = "assets/chars/caldera_king.png",
        stats = {
            health = 165, mana = 0, stamina = 24,
            staminaRegen = 2,
            damage = 16, magicDamage = 0,
            defense = 3, magicDefense = 3,
            movement = 3,
            speed = 4,
            skill = 6, luck = 2,
        },
        resist = { fire = 5, water = -5 },
        startingItems = {
            false,              false,             false,
            "weapon_pseudopod", "utility_caldera_heart", false,
            false,              false,             false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "armor_caldera_plate", "utility_flashpoint" },
        archetype = "aggressive",
    }
