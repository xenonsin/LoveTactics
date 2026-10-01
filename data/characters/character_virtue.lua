-- THE VIRTUE, rung 2: the choir's warden (reviewed 2026-09-30, "Pride's Bestiary").
--
-- Each turn it lays Aegis on the angel that took the most damage last round (Virtue's Aegis). It does not pick;
-- the wound does -- so the body the company has been focusing down is the body that comes up Warded, and a
-- company that cannot debuff the choir has to spread its blows or reach the Virtue first.
--
-- It carries its own drop, the way the Oni Priestess carries her bell. On the priest's table.
return {
    name = "Virtue",
    race = "angel",
    tier = 2,
    sprite = "assets/chars/virtue.png",
    archetype = "support",
    stats = {
        health = 46, mana = 32, stamina = 14,
        staminaRegen = 2, manaRegen = 3,
        damage = 4, magicDamage = 8,
        defense = 3, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 4, luck = 3,
    },
    startingItems = {
        "weapon_choir_light", "ability_virtues_aegis", false,
        false,                false,                   false,
        false,                false,                   false,
    },
    drops = { "ability_virtues_aegis" },
    defaultAction = "weapon_choir_light",
}
