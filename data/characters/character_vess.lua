-- Vess, the Assassin the Hiring Hall offers. A version of the assassin exemplar
-- (data/characters/character_assassin.lua) -- that one is the killer sent for you, and keeps its
-- boss flag and its inflated line; this one is hireable and honest.
--
-- The Quiet Errand (data/items/utility/utility_quiet_errand.lua) is the whole build: it banks the
-- ground she crosses WITHOUT walking, so Shadow Strike and Stillshade are not utility in her grid,
-- they are ammunition.
return {
    name = "Vess",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/vess.png",
    class = "rogue",
    discipline = "assassin",
    archetype = "skirmish",
    stats = {
        health = 92, mana = 8, stamina = 24,
        staminaRegen = 2,
        damage = 21, magicDamage = 3,
        defense = 8, magicDefense = 6,
        movement = 4,
        speed = 6,
    },
    startingItems = {
        "weapon_quietus",      "ability_shadow_strike", "ability_stillshade",
        "ability_coup_de_grace", "utility_quiet_errand", "utility_greyveil_cloak",
        "armor_leather_armor", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_quietus",
    signatureWeapon  = "weapon_quietus",
    signatureAbility = "utility_quiet_errand",
    ai = {
        { priority = "urgent", act = "attack", item = "ability_coup_de_grace", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
