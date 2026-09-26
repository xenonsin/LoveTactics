-- THE GOBLIN FIREBRAND, rung 1: walks in fire and leaves more of it behind (approved as pitched, 2026-09-26,
-- "The Goblins of Wrath").
--
-- Every tile it leaves catches fire, burning ground does not hurt it, and it hits harder standing in fire -- all
-- three are the Firewalker's Wraps it wears, which is also its drop. It carries the existing Fire Bomb rather
-- than a new one. The volcanic ground already spreads fire, and a Firebrand walking through a fight lays down
-- more of it: catch it on bare rock, or kill it at range.
return {
    name = "Goblin Firebrand",
    race = "goblin",
    tier = 1,
    class = "alchemist",
    discipline = "bombardier",
    sprite = "assets/chars/goblin_firebrand.png",
    archetype = "aggressive",
    stats = {
        health = 22, mana = 20, stamina = 14,
        staminaRegen = 3,
        damage = 7, magicDamage = 9,
        defense = 1, magicDefense = 3,
        movement = 4,
        speed = 4,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_dagger", "consumable_fire_bomb", "utility_firewalkers_wraps",
        false,                false,                  false,
        false,                false,                  false,
    },
    drops = { "utility_firewalkers_wraps" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
