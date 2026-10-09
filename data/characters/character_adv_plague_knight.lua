-- PLAGUE KNIGHT, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A
-- race-free body fielded as `character_adv_plague_knight@<race>`; `race` names the first leaning race only
-- so the blueprint loads. Built on the generic knight (the root the exemplar walks): 15 / 4 magic.
--
-- WHAT IT DOES ON THE BOARD (The Contagion, Raise the Fallen, Green Hands): the Miasmal Plate poisons
-- whoever stands beside it, the flail spreads Poison where it lands, and Contagion passes the rot from
-- every poisoned body to the foes standing next to it. No Rot-Fume Gauntlet (the exemplar's scaling
-- damage is a boss line, and this is the body met as traffic) and no Plaguebearer's Draught, which the
-- planner drank after stepping AWAY from the foe it was meant to catch. The counter is the page's: don't
-- trade in melee with it.
return {
    name = "Plague Knight",
    race = "naga",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/plague_knight.png",
    class = "knight",
    discipline = "plague_knight",
    archetype = "aggressive",
    stats = {
        health = 72, mana = 15, stamina = 20,
        staminaRegen = 2,
        damage = 14, magicDamage = 4,
        defense = 11, magicDefense = 6,
        movement = 4,
        speed = 3,
        skill = 3, luck = 2,
    },
    startingItems = {
        "weapon_pestilent_flail", "utility_contagion", "utility_miasmal_plate",
        "armor_chainmail",
    },
    defaultAction = "weapon_pestilent_flail",
    signatureWeapon  = "weapon_pestilent_flail",
    signatureAbility = "utility_contagion",
    -- Wade into the nearest foe; the plate and Contagion do the rest.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
