-- DUELIST, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_duelist@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic rogue (the root the exemplar walks): 8 / 3 magic.
--
-- WHAT IT DOES ON THE BOARD (Open the Line, The Purge): it picks the body in front of it and stays on it.
-- En Garde climbs with every consecutive strike on one foe, Reading the Blade banks Tempo on the same
-- body, and the Poise pays out while exactly one foe stands beside it. Every one of those resets on a
-- switch, which is the counter the page names: rotate who stands at the front. No Coup Droit -- it lands
-- only on a Duelbound foe, and nothing on the duelist's or its parents' shelves applies Duelbound.
return {
    name = "Duelist",
    race = "elf",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/duelist.png",
    class = "rogue",
    discipline = "duelist",
    archetype = "aggressive",
    stats = {
        health = 58, mana = 8, stamina = 22,
        staminaRegen = 2,
        damage = 16, magicDamage = 3,
        defense = 6, magicDefense = 5,
        movement = 4,
        speed = 5,
        skill = 8, luck = 7,
    },
    startingItems = {
        "weapon_main_gauche", "ability_en_garde", "utility_reading_the_blade",
        "utility_duelists_poise", "armor_leather_armor",
    },
    defaultAction = "weapon_main_gauche",
    signatureWeapon  = "weapon_main_gauche",
    signatureAbility = "ability_en_garde",
    -- Lock onto the nearest foe and keep pressing it.
    ai = {
        { priority = "high", act = "attack", item = "ability_en_garde", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
        { priority = "normal", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
