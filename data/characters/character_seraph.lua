-- THE SERAPH, rung 2: the choir's fire (reviewed 2026-09-30, "Pride's Bestiary").
--
-- The Burning One: any foe that starts its turn next to it Burns (its wing, armor_seraphs_wing). It closes and
-- stays close, and the answer is the hit-and-run -- strike it and walk off before your next turn opens beside it.
-- A ranged company barely notices it; a line of shields standing in front of it burns down.
--
-- It wears its own drop, the Seraph's Wing. On the crusader's table.
return {
    name = "Seraph",
    race = "angel",
    tier = 2,
    sprite = "assets/chars/seraph.png",
    archetype = "aggressive",
    stats = {
        health = 50, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 6, magicDamage = 8,
        defense = 3, magicDefense = 5,
        movement = 5, -- 4 after the wing: it has to reach you to burn you
        speed = 4,
        skill = 5, luck = 2,
    },
    startingItems = {
        "weapon_seraph_flame", "armor_seraphs_wing", false,
        false,                 false,                false,
        false,                 false,                false,
    },
    drops = { "armor_seraphs_wing" },
    defaultAction = "weapon_seraph_flame",
}
