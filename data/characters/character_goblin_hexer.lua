-- THE GOBLIN HEXER, rung 2: the Red Mist (approved 2026-09-26, "The Goblins of Wrath"; Seeing Red re-read in
-- round 2 on Keno's note, "lose control of them and they use any action towards any target").
--
-- It lays a 3x3 cloud for two turns, and anyone inside uses a random action on a random target, friend or foe --
-- the goblins too, which do not care. The answer is spacing. A shaman on the mage table, and it keeps back.
return {
    name = "Goblin Hexer",
    race = "goblin",
    tier = 2,
    class = "mage",
    discipline = "shaman",
    sprite = "assets/chars/goblin_hexer.png",
    archetype = "skirmish",
    stats = {
        health = 34, mana = 50, stamina = 10,
        staminaRegen = 2,
        damage = 4, magicDamage = 11,
        defense = 1, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_staff", "ability_red_mist", false,
        false,          false,              false,
        false,          false,              false,
    },
    drops = { "ability_red_mist" },
    defaultAction = "weapon_staff",
    signatureWeapon = "weapon_staff",
}
