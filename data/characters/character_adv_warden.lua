-- WARDEN, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_warden@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic knight (the root the exemplar walks): 15 / 4 magic.
--
-- WHAT IT DOES ON THE BOARD (The Long Invocation): it marks a line and Roots whoever crosses it. The
-- Warding Line drives a snare stake that Roots the foe who walks over it, and needs a bow beside it in the
-- grid -- which is why the hunter's bow sits in cell 3, next to the stake in cell 2 (the exemplar's spear
-- alone could not throw it). The Marchstone Halts whoever comes up beside it. Defensive: it holds its
-- ground in front of the theurge and lays stakes on the approach before anyone has struck it.
return {
    name = "Warden",
    race = "orc",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/warden.png",
    class = "knight",
    discipline = "warden",
    archetype = "defensive",
    stats = {
        health = 70, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 13, magicDamage = 4,
        defense = 12, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_iron_spear", "ability_warding_line", "weapon_iron_bow",
        "utility_marchstone", "armor_chainmail",
    },
    defaultAction = "weapon_iron_spear",
    signatureWeapon  = "weapon_iron_spear",
    signatureAbility = "ability_warding_line",
    -- Strike what has reached the line; otherwise stake the approach while a foe is coming.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "nearest_foe", test = "within", value = 1 } },
        { priority = "high", act = "cast", item = "ability_warding_line",
          when = { subject = "any_foe", test = "within", value = 6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
