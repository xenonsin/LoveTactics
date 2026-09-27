-- THE HORNLESS TWIN: the other half of the Oni Twins' elite (approved 2026-09-26/27, "The Oni of Wrath").
--
-- After Re:Zero's hornless twin. Wind Blades are her cast, and she has no horn to draw mana from, so she draws it
-- from her sister each turn (Borrowed Horn) -- Silence, snap or fell the horned twin and she casts nothing. She sees
-- through the eyes around her: no Invisible foe near her stays hidden (Borrowed Eyes). Strike her, and her sister's
-- horn comes out.
--
-- She drops Borrowed Eyes. An elementalist on the mage table.
return {
    name = "Hornless Twin",
    race = "oni",
    tier = 3,
    class = "mage",
    discipline = "elementalist",
    sprite = "assets/chars/oni_hornless_twin.png",
    archetype = "skirmish",
    stats = {
        health = 82, mana = 16, stamina = 14,
        staminaRegen = 2, manaRegen = 0,
        damage = 5, magicDamage = 12,
        defense = 3, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 5, luck = 5,
    },
    startingItems = {
        "ability_wind_blades",         "utility_borrowed_eyes", "weapon_staff",
        "utility_the_hornless_sister", false,                   false,
        false,                         false,                   false,
    },
    drops = { "utility_borrowed_eyes" },
    defaultAction = "ability_wind_blades",
    signatureWeapon = "weapon_staff",
}
