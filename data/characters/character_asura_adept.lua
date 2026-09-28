-- ASURA ADEPT: the second rung (models/asura.lua). Four arms -- every bare-handed blow lands once more -- and
-- the Swift Fist on top of them, so each punch lands three times and banks three chi. It carries Flurry, which
-- SPENDS 3 chi, and that is what makes it worse than an Acolyte: a smart Adept empties its own pool before it
-- bursts. Furor's stair escort.
--
-- Imagery: a Khon masked-dance demon.
return {
    name = "Asura Adept",
    race = "asura",
    tier = 2,
    class = "priest",
    discipline = "monk",
    sprite = "assets/chars/asura_adept.png",
    archetype = "aggressive",
    stats = {
        health = 56, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 4, magicDefense = 3,
        movement = 4,
        speed = 3, -- 4 after the race
        skill = 4, luck = 3, -- 5 after the race
    },
    startingItems = {
        "utility_four_arms", "utility_iron_fist", "utility_swift_fist",
        "ability_flurry",    false,               false,
        false,               false,               false,
    },
    signatureWeapon = "utility_iron_fist",
    signatureAbility = "ability_flurry",
}
