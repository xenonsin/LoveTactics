-- Marek, the Warlord the Hiring Hall offers.
--
-- A VERSION of the warlord exemplar (data/characters/character_warlord.lua), which stays where it is
-- as the boss of its own gate quest. This one is hireable, so it carries the honest line rather than
-- the inflated one -- and The Last Order, which spends the banners rather than planting a sixth
-- (data/items/utility/utility_last_order.lua).
--
-- He is built around the ground he lays: three standards in the grid, because the relic's census
-- counts allies standing in them and a warlord who has planted nothing has nobody to give an order to.
return {
    name = "Marek",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/marek.png",
    class = "fighter",
    discipline = "warlord",
    archetype = "defensive",
    stats = {
        health = 140, mana = 5, stamina = 25,
        staminaRegen = 2,
        damage = 26, magicDamage = 3,
        defense = 11, magicDefense = 10,
        movement = 4,
        speed = 2,
    },
    startingItems = {
        "weapon_iron_sword",   "ability_muster_banner", "ability_rally_banner",
        "utility_pincer_banner", "utility_last_order",  "consumable_war_drums",
        "armor_chainmail",     "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "utility_last_order",
    ai = {
        { priority = "high", act = "cast", item = "ability_rally_banner",
          when = { subject = "any_ally", test = "exists" } },
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
