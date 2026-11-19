-- THE ORC VETERAN, rung 1: a Grunt that has done this before (2026-09-26, "The Orcs of Wrath"). The Veterans fight
-- was approved as Grunts that open already Proven; this is that Grunt as its own blueprint -- the Grunt's body with
-- Old Scars, so it opens every fight Proven twice over (+4 Damage, +4 Defense) and one more kill makes it three.
-- Split from the Grunt rather than scarred by the encounter, which is the split-the-blueprint rule
-- (character-basic-tactics): a fight hands out bodies, not states.
--
-- ITS LEVER IS ORDER (2026-11-19, the creature identity pass): PASSED SCARS. When it falls, the nearest orc of its
-- side takes its Proven (trait_passed_scars, on Old Scars). Of the two levers the review offered -- refuse its
-- first lethal blow, or hand its Proven on -- this one is the orcs' own rule, shows as a badge moving from one token
-- to another, and decides who dies first: cut the Grunts around a Veteran down before it, or catch it alone.
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
    ai = require("models.wrath_targeting").orc, -- the killing blow (2026-11-19)
}
