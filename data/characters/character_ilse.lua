-- Ilse, the Sentinel the Hiring Hall offers.
--
-- A VERSION of the sentinel exemplar (data/characters/character_sentinel.lua), which stays where it is
-- as the Knight in Grey's own body. Hers carries The Standing Debt (data/items/armor/armor_standing_debt.lua)
-- -- intercept taken past the point where it is a favour: for two turns nothing on the board may aim
-- at anybody else.
--
-- `guards = "priority"` for the same reason Rowan has it: a sentinel's post is not the map's to name.
-- She rings whoever cannot stand for themselves and holds there, whatever the objective says.
return {
    name = "Ilse",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/ilse.png",
    class = "knight",
    discipline = "sentinel",
    archetype = "defensive",
    guards = "priority",
    stats = {
        health = 100, mana = 15, stamina = 16,
        staminaRegen = 2,
        damage = 14, magicDamage = 4,
        defense = 15, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_iron_sword",  "ability_shared_burden", "ability_single_combat",
        "ability_straw_sentry", "armor_standing_debt", "utility_lent_aegis",
        "utility_unyielding_seal", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "armor_standing_debt",
    ai = {
        { priority = "urgent", act = "cast", item = "armor_standing_debt",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 } },
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
