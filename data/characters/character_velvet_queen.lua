-- THE VELVET QUEEN: the velvet slime (data/characters/character_velvet_slime.lua) crowned -- an elite on
-- Lust's seat floor (data/encounters/encounter_the_velvet_queen.lua).
--
-- Her blows take two pieces at once (utility_velvet_train), and when she falls she comes apart into
-- three velvet slimes with her wardrobe shared out among them (trait_velvet_split) -- so a company that
-- wants its armour back has to put every piece down, and each one gives back what it is wearing.
--
-- `boss = true` for the King's reasons (Coup de Grace must not skip the split), and fielded under
-- `killAll` -- never an `assassinate` mark.
return {
    name = "Velvet Queen",
    race = "beast",
    tier = 4,
    boss = true,
    sprite = "assets/chars/velvet_queen.png",
    stats = {
        health = 165, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 16, magicDamage = 0,
        defense = 3, magicDefense = 3,
        movement = 3,
        speed = 4,
        skill = 6, luck = 2,
    },
    resist = { fire = 5, ice = -5 },
    startingItems = {
        false,              false,                  false,
        "weapon_pseudopod", "utility_velvet_train", false,
        false,              false,                  false,
    },
    defaultAction = "weapon_pseudopod",
    -- HER OWN THREE, and only her own (docs/drops.md): her admirers' coats worn (the Suitors), her
    -- presence worn (the Laces) and the answer to her whole line (the Lining). The Borrowed Finery that
    -- stood here was cut (2026-09-24) -- "kill it and wear what it had" was Gula's Maw again.
    drops = { "utility_kept_suitors", "utility_loosened_laces", "armor_silk_lining" },
    archetype = "aggressive",
}
