-- THE ONI, rung 1: the clan's line body (approved 2026-09-26, "The Oni of Wrath", round 1).
--
-- A named clan warrior with a sword, the Horn and the Witch's Taint (utility_oni_blood, granted by the race) and
-- nothing else -- the body the rest of the clan is read against. Two of them are the Horn's teaching fight: fell
-- one and the other comes for whoever did it.
--
-- It drops the Oni Horn, the racial rule rebuilt for a person.
return {
    name = "Oni",
    race = "oni",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/oni.png",
    archetype = "aggressive",
    stats = {
        health = 58, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 4, magicDefense = 2,
        movement = 4,
        speed = 3,
        skill = 4, luck = 4,
    },
    startingItems = {
        "weapon_iron_sword", false, false,
        false,               false, false,
        false,               false, false,
    },
    drops = { "utility_oni_horn" },
    defaultAction = "weapon_iron_sword",
    signatureWeapon = "weapon_iron_sword",
}
