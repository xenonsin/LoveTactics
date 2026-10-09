-- SHAMAN, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_shaman@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic archer (the hunter root the exemplar walks): 15 / 3 magic.
--
-- WHAT IT DOES ON THE BOARD (The Bait, The Summoning): it keeps a wind spirit fighting beside the party,
-- hastened by the Ghost Wind, and shoots from range. Call Spirit RESERVES a fifth of the pool rather than
-- spending it, so the hunter's fifteen mana holds the spirits it can afford and no more -- the ceiling is
-- the pool, not a rule -- and it calls only when nothing is in bow range, so a spirit is the opening of
-- the fight rather than every turn of it. The Spirit Fetish inspires whoever stands beside it.
return {
    name = "Shaman",
    race = "naga",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/shaman.png",
    class = "hunter",
    discipline = "shaman",
    archetype = "skirmish",
    stats = {
        health = 52, mana = 15, stamina = 22,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_bow", "ability_call_spirit", "utility_ghost_wind",
        "utility_spirit_fetish", "ability_lay_the_hex", "armor_silk_robes",
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_call_spirit",
    -- Shoot what the bow reaches; call a spirit while the fight is still coming to it.
    ai = {
        { priority = "high", act = "attack", item = "weapon_iron_bow", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
        { priority = "normal", act = "cast", item = "ability_call_spirit",
          when = { subject = "any_foe", test = "within", value = 8 } },
    },
}
