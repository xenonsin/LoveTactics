-- Fen, the Skirmisher the Hiring Hall offers. A version of the skirmisher exemplar
-- (data/characters/character_skirmisher.lua, the raider outrider), which stays put.
--
-- Ground Given (data/items/utility/utility_ground_given.lua) banks tiles WALKED, so the relic is
-- charged by playing her properly and by nothing else -- being shoved banks nothing, which is enforced
-- at the seam rather than in the file. Running Shot already scales with the same distance.
return {
    name = "Fen",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/fen.png",
    class = "hunter",
    discipline = "skirmisher",
    archetype = "skirmish",
    stats = {
        health = 108, mana = 15, stamina = 24,
        staminaRegen = 2,
        damage = 20, magicDamage = 3,
        defense = 9, magicDefense = 6,
        movement = 5,
        speed = 5,
    },
    startingItems = {
        "weapon_harriers_bow", "ability_harrying_strike", "ability_running_shot",
        "ability_break_off",   "utility_ground_given",    "utility_skirmishers_momentum",
        "armor_outriders_harness", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_harriers_bow",
    signatureWeapon  = "weapon_harriers_bow",
    signatureAbility = "utility_ground_given",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
