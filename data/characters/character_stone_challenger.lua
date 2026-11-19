-- A STONE CHALLENGER: one of the three statues in Medusa's garden (encounter_envy_medusa; models/gorgon.lua). A
-- past challenger who came for her head and met her eyes. It opens the fight Petrified and held so (its organ,
-- utility_turned_to_stone), taking half damage and doing nothing, until Medusa falls to half health -- then it
-- cracks open and fights with the fists it was turned holding up.
--
-- A CONSTRUCT, because what steps down is stone, not the man: nothing human is fielded on the waste. Its kit is the
-- earth elemental's Stone Fists, the body's own weapon now.
--
-- IDENTITY LEVER (creature identity pass, 2026-11-19): ORDER. Cracked open it used to be a plain Stone-Fists
-- bruiser. Now it carries Medusa's gaze in its fists: every blow it lands gives the target 1 Stone (its organ's
-- trait_turned_to_stone; 3 Stone is Petrified for 2 turns), so the challengers are killed before they stone the
-- front line, and the company that let her gaze stack Stone walks into her half health already halfway there.
-- TARGETING: it goes for the foe carrying the most Stone it can reach, to finish what her eyes started
-- (models/envy_oneoffs.lua's plan).
return {
    name = "Stone Challenger",
    race = "construct",
    tier = 2,
    sprite = "assets/chars/stone_challenger.png",
    stats = {
        health = 60, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 7, magicDefense = 3,
        movement = 3,
        speed = 4,
        skill = 5, luck = 2,
    },
    -- Stone turns an edge and breaks under a hammer (docs/bestiary.md: a redistribution, summing to zero).
    resist = { slash = 3, impact = -3 },
    startingItems = { "weapon_stone_fists", "utility_turned_to_stone" },
    defaultAction = "weapon_stone_fists",
    archetype = "aggressive",
}
