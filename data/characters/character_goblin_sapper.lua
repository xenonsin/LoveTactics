-- THE GOBLIN SAPPER, rung 1: sets kegs and runs (approved as pitched, 2026-09-26, "The Goblins of Wrath").
--
-- It carries the bombardier's own Powder Keg -- nothing new to build -- and sets it beside the fight. Any hit
-- sets a keg off, a Fanatic's spin or a Firebrand's fire included, so a floor of Sappers and Firebrands makes
-- the fight's own fire the fuse. A bombardier on the alchemist table, and it keeps its distance (skirmish).
return {
    name = "Goblin Sapper",
    race = "goblin",
    tier = 1,
    class = "alchemist",
    discipline = "bombardier",
    sprite = "assets/chars/goblin_sapper.png",
    archetype = "skirmish",
    stats = {
        health = 18, mana = 36, stamina = 12,
        staminaRegen = 2,
        damage = 6, magicDamage = 9,
        defense = 1, magicDefense = 2,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    startingItems = {
        "weapon_iron_dagger", "ability_powder_keg", false,
        false,                false,                false,
        false,                false,                false,
    },
    drops = { "ability_powder_keg" },
    defaultAction = "weapon_iron_dagger",
    signatureWeapon = "weapon_iron_dagger",
}
