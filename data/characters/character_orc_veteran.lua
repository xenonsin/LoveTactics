-- THE ORC VETERAN, rung 1: a Grunt that has done this before (2026-09-26, "The Orcs of Wrath"). The Veterans fight
-- was approved as Grunts that open already Proven; this is that Grunt as its own blueprint -- the Grunt's body with
-- Old Scars, so it opens every fight Proven twice over (+4 Damage, +4 Defense) and one more kill makes it three.
-- Split from the Grunt rather than scarred by the encounter, which is the split-the-blueprint rule
-- (character-basic-tactics): a fight hands out bodies, not states.
return {
    name = "Orc Veteran",
    race = "orc",
    tier = 1,
    class = "fighter",
    sprite = "assets/chars/orc_veteran.png",
    archetype = "aggressive",
    stats = {
        health = 28, mana = 0, stamina = 18,
        staminaRegen = 3,
        damage = 8, magicDamage = 0,
        defense = 3, magicDefense = 1,
        movement = 4,
        speed = 3,
        skill = 5, luck = 3,
    },
    startingItems = {
        "weapon_iron_axe", "ability_shieldbreak", "utility_old_scars",
        false,             false,                 false,
        false,             false,                 false,
    },
    drops = { "utility_orc_scars" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
}
