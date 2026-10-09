-- THE ADVENTURER WARLORD ("The Rift's Adventurers", approved 2026-10-09; models/adventurers.lua). A
-- race-free body: fielded as `character_adv_warlord@<race>`; `race` is only the class's first leaning
-- race, so the bare blueprint loads.
--
-- Line (tier 2), as every earned class is, on the generic Fighter's base -- not the Warlord boss's
-- inflated line. It plants first and fights second: the Rally Banner and the Muster Banner stack their
-- fields, and Banner and Beast, the Summoning and the Last Stand all fight inside them. Its counter is
-- the banner's: break it, or fight off it.
return {
    name = "Warlord",
    race = "orc",
    tier = 2,
    adventurer = true,
    class = "fighter",
    discipline = "warlord",
    sprite = "assets/chars/warlord.png",
    archetype = "aggressive",
    stats = {
        health = 68, mana = 5, stamina = 25,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 9, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 6, luck = 3,
    },
    startingItems = {
        "weapon_iron_hammer", "ability_rally_banner", "ability_muster_banner",
        "armor_rally_coat", "consumable_war_drums", "utility_closed_ranks",
        "consumable_healing_potion",
    },
    defaultAction = "weapon_iron_hammer",
    signatureWeapon = "weapon_iron_hammer",
    signatureAbility = "ability_rally_banner",
    ai = {
        -- The field goes down before the fight comes to it.
        { priority = "high", act = "support", item = "ability_rally_banner",
          when = { subject = "any_ally", test = "count_at_least", value = 2 } },
        { priority = "high", act = "cast", item = "ability_muster_banner",
          when = { subject = "any_foe", test = "within", value = 4 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
