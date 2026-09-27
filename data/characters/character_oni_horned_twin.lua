-- THE HORNED TWIN: one half of the Oni Twins' elite, on Wrath's approach (approved 2026-09-26/27, "The Oni of
-- Wrath": the Twins were a pair in round 1, and round 2 made them an elite on the author's note).
--
-- After Re:Zero's twins. Her morning star reaches 3 and drags; she casts water. Strike her sister and her horn comes
-- out; fell her sister and it comes ALL the way out -- the Sweep strikes every foe within 3 and she heals a fifth of
-- her health each turn. Fell her first instead, and her sister has no mana left to draw.
--
-- She drops the Morning Star.
return {
    name = "Horned Twin",
    race = "oni",
    tier = 3,
    class = "fighter",
    sprite = "assets/chars/oni_horned_twin.png",
    archetype = "aggressive",
    stats = {
        health = 96, mana = 36, stamina = 24,
        staminaRegen = 3, manaRegen = 2,
        damage = 12, magicDamage = 8,
        defense = 5, magicDefense = 4,
        movement = 4,
        speed = 3,
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_morning_star",       "ability_the_sweep", "ability_water_ball",
        "utility_the_horned_sister", false,               false,
        false,                       false,               false,
    },
    drops = { "weapon_morning_star" },
    defaultAction = "weapon_morning_star",
    signatureWeapon = "weapon_morning_star",
}
