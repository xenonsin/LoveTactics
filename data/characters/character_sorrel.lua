-- Sorrel, the Herbalist the Hiring Hall offers. A version of the herbalist exemplar
-- (data/characters/character_herbalist.lua, the field-apothecary), which stays put.
--
-- The Culler's Basket (data/items/utility/utility_cullers_basket.lua) puts nothing in a grid -- it pays
-- the party directly, which is the answer to "what if the grid is full". Field Brew and Distil make the
-- ground she then harvests, so she can farm her own gate.
return {
    name = "Sorrel",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/sorrel.png",
    class = "alchemist",
    discipline = "herbalist",
    archetype = "support",
    stats = {
        health = 84, mana = 45, stamina = 16,
        staminaRegen = 2,
        damage = 12, magicDamage = 12,
        defense = 7, magicDefense = 8,
        movement = 4,
        speed = 4,
    },
    startingItems = {
        "weapon_apothecarys_lancet", "ability_field_brew", "ability_distil",
        "consumable_wildcraft_poultice", "utility_cullers_basket", "utility_cullers_kit",
        "consumable_bitterroot_draught", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_apothecarys_lancet",
    signatureWeapon  = "weapon_apothecarys_lancet",
    signatureAbility = "utility_cullers_basket",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
