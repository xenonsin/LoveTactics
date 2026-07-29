-- Plague Knight exemplar (knight x alchemist multiclass). Contagion: melee spreads poison, and
-- standing beside it sickens. Met as a boss -- the Forsworn Knight shows it in its unlock quest, but
-- that body (character_forsworn_knight) is a story-critical Bastion-line enemy, so the discipline
-- exemplar is authored here with the full Plague Knight kit. Home shelf is knight (Pestilent Flail).
-- Kit from data/disciplines/plague_knight.lua.
return {
    name = "Plague Knight",
    sprite = "assets/chars/forsworn_knight.png",
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
    -- Wade into the nearest foe; Contagion spreads the rot from there.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
