    -- THE RIME SLIME: one of Sloth's three slimes (floors 9-10, the tundra). Its rule is TORPOR
-- (data/traits/trait_torpid_touch.lua): its blows push your next turn back. Sloth takes time.
    return {
        name = "Rime Slime",
        race = "beast",
        tier = 2,
        sprite = "assets/chars/rime_slime.png",
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
        "weapon_pseudopod", "utility_rime_body", false,
        false,              false,              false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "armor_unhurried_coat" },
        archetype = "aggressive",
    }
