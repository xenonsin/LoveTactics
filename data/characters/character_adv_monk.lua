-- ADVENTURER: the race-free Monk a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_monk@<race>` (models/adventurers.lua); `race` below is only the class's first leaning
-- race, so the base blueprint loads. The priest template's magic pair whole, with the body leaned
-- toward the fists it fights with.
--
-- HE BANKS CHI AND SPENDS IT ALL ON ONE BLOW (Raise the Fallen, Bottom of the Cup). No weapon: the
-- fists are the weapon, and the charms make them land harder and twice. Asura Strike on a body close
-- to falling, Flurry once three chi are banked, bare hands until then.
return {
    name = "Monk",
    race = "oni",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/monk.png",
    class = "priest",
    discipline = "monk",
    archetype = "aggressive",
    stats = {
        health = 62, mana = 70, stamina = 18,
        staminaRegen = 2,
        damage = 12, magicDamage = 12,
        defense = 7, magicDefense = 11,
        movement = 4,
        speed = 5,
        skill = 5, luck = 6,
    },
    startingItems = {
        "utility_iron_fist",   "utility_swift_fist",        "ability_asura_strike",
        "ability_flurry",      "armor_leather_armor",       "consumable_healing_potion",
    },
    signatureWeapon  = "utility_iron_fist",
    signatureAbility = "ability_asura_strike",
    ai = {
        { priority = "urgent", act = "attack", item = "ability_asura_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.4 } },
        { priority = "high", act = "attack", item = "ability_flurry",
          when = { subject = "any_foe", test = "within", value = 1 } },
    },
}
