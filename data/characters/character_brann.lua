-- Brann, the Barbarian the Hiring Hall offers.
--
-- A VERSION of the barbarian exemplar (data/characters/character_barbarian.lua), which stays exactly
-- where it is: that one is the arena berserker you meet on a floor, unnamed and boss-flagged. This one
-- has a name, an honest stat line, and the bound relic that turns the kit into a build -- The Red
-- Account, which reads the health he has already spent (data/items/utility/utility_red_account.lua).
--
-- The magic side is the fighter template's exactly (mana 5 / magicDamage 3). A zero there would be an
-- equip gate hiding in the data -- class is a vendor shelf and never gates gear -- so every hero on
-- this roster inherits its class's pair unchanged.
return {
    name = "Brann",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/brann.png",
    class = "fighter",
    discipline = "barbarian",
    archetype = "aggressive",
    stats = {
        health = 128, mana = 5, stamina = 26,
        staminaRegen = 2,
        damage = 24, magicDamage = 3,
        defense = 9, magicDefense = 6,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_crimson_greataxe", "ability_fury",          "ability_reckless_stance",
        "ability_desperate_strike", "utility_red_account",  "utility_vampiric_strike",
        "armor_leather_armor",     "consumable_healing_potion", false,
    },
    defaultAction = "weapon_crimson_greataxe",
    signatureWeapon  = "weapon_crimson_greataxe",
    signatureAbility = "utility_red_account",
    ai = {
        { priority = "urgent", act = "cast", item = "utility_red_account",
          when = { subject = "self", test = "hp_pct_below", value = 0.6 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
