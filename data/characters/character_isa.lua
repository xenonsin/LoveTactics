-- Isa, the Summoner the Hiring Hall offers. A version of the summoner exemplar
-- (data/characters/character_summoner.lua, the conjurer with an elemental court), which stays put.
--
-- The Court Kept Waiting (data/items/utility/utility_court_kept_waiting.lua) is a payoff for HAVING
-- summoned rather than a fourth summon: three standing braces and quickens all of them, each lent force
-- by the others. Losing one shuts the gate, which is the pressure a tally could never apply.
return {
    name = "Isa",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/isa.png",
    class = "mage",
    discipline = "summoner",
    archetype = "skirmish",
    stats = {
        health = 84, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 5, magicDefense = 12,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_staff",                     "ability_summon_earth_elemental", "ability_summon_ice_elemental",
        "ability_summon_lightning_elemental", "utility_court_kept_waiting",   "ability_summon_wind_elemental",
        "utility_mana_wellspring",          "consumable_healing_potion",      false,
    },
    defaultAction = "ability_summon_earth_elemental",
    signatureWeapon  = "weapon_staff",
    signatureAbility = "utility_court_kept_waiting",
    ai = {
        { priority = "high", act = "cast", item = "ability_summon_earth_elemental",
          when = { subject = "any_foe", test = "exists" } },
    },
}
