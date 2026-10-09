-- ADVENTURER: the race-free Summoner a party fields ("The Rift's Adventurers", 2026-10-09). Fielded as
-- `character_adv_summoner@<race>` (models/adventurers.lua); `race` below is only the class's first
-- leaning race, so the base blueprint loads. The mage template, a little sturdier.
--
-- HE BANKS MANA AND FIELDS ELEMENTALS (the Summoning, the Sigil Choir, the Bait). Three calls, each
-- reserving a quarter of the pool while its elemental stands; the Wellspring is what lets the pool come
-- back between them. Every call is refused while its own elemental is still up, so the rules below
-- simply walk down the list. Kill him and the elementals stop coming.
--
-- THE SUMMON RULES DO NOT FIRE YET, and the exemplar's do not either. An elemental is called onto an
-- EMPTY tile, and the planner only aims at tiles a body stands on (no `aiAims` on the summons); and a
-- summon is not flagged support, so models/ai.lua's MUTATION credit would not reach it if it could aim.
-- Until both land he fights with the staff.
return {
    name = "Summoner",
    race = "kobold",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/summoner.png",
    class = "mage",
    discipline = "summoner",
    archetype = "skirmish",
    stats = {
        health = 46, mana = 80, stamina = 10,
        staminaRegen = 1,
        damage = 5, magicDamage = 18,
        defense = 4, magicDefense = 12,
        movement = 4,
        speed = 3,
        skill = 6, luck = 4,
    },
    startingItems = {
        "weapon_staff",                   "ability_summon_fire_elemental", "ability_summon_earth_elemental",
        "ability_summon_ice_elemental",   "utility_mana_wellspring",       "armor_silk_robes",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_staff",
    signatureWeapon  = "weapon_staff",
    signatureAbility = "ability_summon_fire_elemental",
    ai = {
        { priority = "emergency", act = "retreat", when = { subject = "self", test = "hp_pct_below", value = 0.3 } },
        { priority = "high", act = "cast", item = "ability_summon_fire_elemental",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "cast", item = "ability_summon_earth_elemental",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "high", act = "cast", item = "ability_summon_ice_elemental",
          when = { subject = "any_foe", test = "exists" } },
        { priority = "normal", act = "attack", item = "weapon_staff", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
