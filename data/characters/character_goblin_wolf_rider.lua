-- THE GOBLIN WOLF-RIDER, rung 2: two bodies in one (approved as pitched, 2026-09-26, "The Goblins of Wrath").
--
-- The first lethal blow kills only half of it (War Saddle, trait_two_in_one). Shot from range, the rider falls
-- and the wolf goes wild -- Seeing Red, biting whatever is nearest on either side. Cut down up close, the wolf
-- falls and the rider rolls clear as a Goblin Cutter. So which one you kill first changes the fight, and the
-- goblins' weakness to the bow decides it. It reuses the Wolf, so it costs little to build.
--
-- No drop of its own: it drops what the wolf drops (character_wolf_grunt).
return {
    name = "Goblin Wolf-Rider",
    race = "goblin",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/goblin_wolf_rider.png",
    archetype = "aggressive",
    stats = {
        health = 44, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 6, -- mounted
        speed = 5,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_spear", "utility_war_saddle", false,
        false,               false,                false,
        false,               false,                false,
    },
    drops = { "utility_endurance", "armor_runners_hide" }, -- the wolf's
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
}
