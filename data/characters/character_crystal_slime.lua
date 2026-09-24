    -- THE CRYSTAL SLIME: Pride's slime (floors 13-14, the spire). Its rule is RANK (data/traits/trait_rank.lua):
-- only the lowest-health crystal on the board can be hurt, so a company kills them from the bottom up.
-- Proof against steel like the fen's slime.
    return {
        name = "Crystal Slime",
        race = "beast",
        tier = 2,
        sprite = "assets/chars/crystal_slime.png",
        stats = {
            health = 44, mana = 0, stamina = 16,
            staminaRegen = 2,
            damage = 12, magicDamage = 0,
            defense = 2, magicDefense = 2,
            movement = 3,
            speed = 4,
            skill = 4, luck = 2,
        },
        resist = { holy = 3, dark = -3 },
        startingItems = {
            false,              false,              false,
        "weapon_pseudopod", "utility_crystal_body", false,
        false,              false,              false,
        },
        defaultAction = "weapon_pseudopod",
        -- ITS OWN PIECES, and only its own (docs/drops.md).
        drops = { "utility_pecking_order" },
        archetype = "aggressive",
    }
