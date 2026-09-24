    -- THE MANY-FACED KING: the mimic slime crowned -- an elite on Envy's seat floor. When it falls it comes
-- apart into copies of three members of the company, each wearing the blessings it had begrudged.
    --
    -- `boss = true` for the King Slime's reasons (Coup de Grace must not skip the split), and fielded
    -- under `killAll` -- never an `assassinate` mark.
    return {
        name = "Many-Faced King",
        race = "beast",
        tier = 4,
        boss = true,
        sprite = "assets/chars/many_faced_king.png",
        stats = {
            health = 165, mana = 0, stamina = 24,
            staminaRegen = 2,
            damage = 16, magicDamage = 0,
            defense = 3, magicDefense = 3,
            movement = 3,
            speed = 4,
            skill = 6, luck = 2,
        },
        resist = { lightning = 5, water = -5 },
        startingItems = {
            false,              false,             false,
            "weapon_pseudopod", "utility_many_faces", false,
            false,              false,             false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_mirror_mask", "utility_second_self" },
        archetype = "aggressive",
    }
