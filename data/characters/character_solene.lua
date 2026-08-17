-- Solene, the Paladin the Hiring Hall offers. A version of the paladin exemplar
-- (data/characters/character_paladin.lua, the sworn holy knight), which stays put.
--
-- The Held Oath (data/items/armor/armor_held_oath.lua) wards the party and pulls what ails them onto
-- her. Vow-Marked Plate is the other half: it hardens her for every debuff she carries, so the Oath's
-- cost is the Plate's fuel. Buy both or neither.
return {
    name = "Solene",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/solene.png",
    class = "knight",
    discipline = "paladin",
    archetype = "support",
    guards = "priority",
    stats = {
        health = 104, mana = 15, stamina = 16,
        staminaRegen = 2,
        damage = 15, magicDamage = 4,
        defense = 15, magicDefense = 11,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_mace",   "ability_lay_on_hands", "ability_consecrate",
        "ability_oathkeepers_litany", "armor_held_oath", "armor_vow_marked_plate",
        "utility_martyrs_icon", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_mace",
    signatureWeapon  = "weapon_iron_mace",
    signatureAbility = "armor_held_oath",
    ai = {
        { priority = "high", act = "support", item = "ability_lay_on_hands", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
    },
}
