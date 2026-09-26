-- THE BUGBEAR, rung 2: the ambush (approved 2026-09-26, "The Goblins of Wrath"; its class picked in round 2 as
-- hunter / poacher, on Keno's note "don't be assassin, that's Redcap").
--
-- A big hairy goblin that starts the fight Invisible on a flank (its Ambusher's Hood, which is its drop). A blow
-- struck on a turn it opened unseen deals double damage and Stuns (From Hiding). It is the trap from Keno's list
-- as a body, and the one goblin threat that does not come from chasing the Feud. A poacher: waiting in cover for
-- prey. Elite band, so it never cowers alone.
return {
    name = "Bugbear",
    race = "goblin",
    tier = 3,
    class = "hunter",
    discipline = "poacher",
    sprite = "assets/chars/bugbear.png",
    archetype = "aggressive",
    stats = {
        health = 96, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 14, magicDamage = 0,
        defense = 5, magicDefense = 3,
        movement = 5,
        speed = 4,
        skill = 7, luck = 4,
    },
    startingItems = {
        "weapon_iron_mace", "ability_from_hiding", "utility_ambushers_hood",
        false,              false,                 false,
        false,              false,                 false,
    },
    drops = { "utility_ambushers_hood" },
    defaultAction = "weapon_iron_mace",
    signatureWeapon = "weapon_iron_mace",
}
