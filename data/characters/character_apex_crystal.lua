    -- THE APEX CRYSTAL: the top of Pride's order -- an elite on Pride's seat floor, and the seat's first elite
-- since the Peerless was cut. It cannot be hurt while any crystal beneath it stands, and when it falls its
-- pieces form a new order.
    --
    -- `boss = true` for the King Slime's reasons (Coup de Grace must not skip the split), and fielded
    -- under `killAll` -- never an `assassinate` mark.
    return {
        name = "Apex Crystal",
        race = "beast",
        tier = 4,
        boss = true,
        sprite = "assets/chars/apex_crystal.png",
        stats = {
            health = 165, mana = 0, stamina = 24,
            staminaRegen = 2,
            damage = 16, magicDamage = 0,
            defense = 3, magicDefense = 3,
            movement = 3,
            speed = 4,
            skill = 6, luck = 2,
        },
        resist = { holy = 5, dark = -5 },
        startingItems = {
            false,              false,             false,
            "weapon_pseudopod", "utility_apex_facet", false,
            false,              false,             false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_station", "armor_above_reproach" },
        archetype = "aggressive",
    }
