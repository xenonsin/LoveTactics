-- MEDUSA, THE GORGON: Envy's approach-floor elite (reviewed 2026-10-01..03, "Envy's Bestiary", row md_body,
-- approved; a general candidate in round 2, an elite from round 3). Cursed out of a goddess's jealousy, and
-- envious now of every living face; in Ovid her blood fell as snakes on the Libyan desert, which is the waste.
--
-- A NAGA, the game's serpent-folk (data/races/naga.lua): scale that turns a blade, a spear that finds the gaps,
-- and lightning that kills them. A gorgon is a serpent-woman, and the race says so without a race of one.
--
-- HER RULES ride on her organ (utility_stone_gaze; a blueprint's own `traits` field is never collected), and
-- models/gorgon.lua argues them: Stone Gaze (a foe ending its turn in her sight within 4 gains Stone; 3 Stone
-- petrify for 2 turns), her blood (a slashing blow that cuts her springs an adder beside her), her garden (three
-- Petrified statues of past challengers, encounter_envy_medusa, crack open at her half health), and Perseus (a
-- body carrying the Hand-Mirror or the Polished Shield gains no Stone and turns it back on her).
--
-- Tier 4 by the review's tag, beside the Many-Faced King; `boss`, off the execute and Charm tables like every
-- elite. She is met again on later trips, so every rule reads the board in front of it.
return {
    name = "Medusa, the Gorgon",
    race = "naga",
    tier = 4,
    boss = true,
    sprite = "assets/chars/medusa.png",
    stats = {
        health = 170, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 14, magicDamage = 0,
        defense = 6, magicDefense = 9,
        movement = 5, -- the race takes one: she is slow on dry ground, and her eyes do the reaching
        speed = 4,
        skill = 7, luck = 5,
    },
    startingItems = {
        false, "weapon_serpent_hair", false,
        false, "utility_stone_gaze",  false,
        false, false,                 false,
    },
    -- Her own pieces (docs/drops.md): her stare as a shaman's, her hair as a poisoner's coat, and the mirror that
    -- answers her. Shallow to deep, which within one list is the rarity.
    drops = { "ability_gorgons_gaze", "armor_serpent_locks", "utility_hand_mirror" },
    defaultAction = "weapon_serpent_hair",
    archetype = "aggressive",
}
