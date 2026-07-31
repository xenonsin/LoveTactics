-- Plague Knight exemplar (knight x alchemist multiclass). Contagion: melee spreads poison, and
-- standing beside it sickens. Met as a boss -- the Forsworn Knight shows it in its unlock quest, but
-- that body (character_forsworn_knight) is a story-critical Bastion-line enemy, so the discipline
-- exemplar is authored here with the full Plague Knight kit. Home shelf is knight (Pestilent Flail).
-- Kit from data/disciplines/plague_knight.lua.
return {
    name = "Plague Knight",
    sprite = "assets/chars/plague_knight.png",
    boss = true,
    class = "knight",
    -- Wades in poisoned and lets proximity do the work (models/ai.lua `aggressive`).
    archetype = "aggressive",
    stats = {
        health = 120, mana = 25, stamina = 18,
        staminaRegen = 2,
        damage = 18, magicDamage = 10,
        defense = 14, magicDefense = 9,
        movement = 4,
        speed = 3,
    },
    startingItems = {
        "weapon_pestilent_flail", "utility_contagion",   "utility_miasmal_plate",
        "utility_rot_fume_gauntlet", "consumable_plaguebearers_draught", "armor_chainmail",
        "consumable_healing_potion", false,             false,
    },
    defaultAction = "weapon_pestilent_flail",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_pestilent_flail",
    signatureAbility = "utility_contagion",
    -- Wade into the nearest foe; Contagion spreads the rot from there.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
