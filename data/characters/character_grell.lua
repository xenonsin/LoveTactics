-- Grell, the Plague Knight the Hiring Hall offers. A version of the plague-knight exemplar
-- (data/characters/character_plague_knight.lua, the Forsworn Knight), which stays put.
--
-- The Sealed Bell (data/items/utility/utility_sealed_bell.lua) spreads ANY affliction, not poison --
-- that is the split with Zosia, whose Mother Vat cashes poison in and ends it. Rot-Fume Gauntlet scales
-- his damage with how many are afflicted, so the bell is what makes that number large.
return {
    name = "Grell",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/grell.png",
    class = "alchemist",
    discipline = "plague_knight",
    archetype = "aggressive",
    stats = {
        health = 120, mana = 45, stamina = 18,
        staminaRegen = 2,
        damage = 18, magicDamage = 12,
        defense = 14, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_pestilent_flail", "utility_contagion",   "utility_miasmal_plate",
        "utility_rot_fume_gauntlet", "utility_sealed_bell", "consumable_plaguebearers_draught",
        "armor_chainmail",      "consumable_healing_potion", false,
    },
    defaultAction = "weapon_pestilent_flail",
    signatureWeapon  = "weapon_pestilent_flail",
    signatureAbility = "utility_sealed_bell",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
