-- THE MINOTAUR: one mythical beast, alone at the heart of a labyrinth, on Wrath's second floor. Reviewed over
-- four rounds, 2026-09-26/27 ("The Minotaur"). It is NOT a race and it has no clan -- the author struck both --
-- and it fights as a BARBARIAN: the fight is hard because of what it carries, not because of who is with it.
--
--   THE LABYRINTH / THROUGH THE WALLS / THE MAZE SHIFTS / HEAD DOWN   its organ (models/labyrinth.lua)
--   THE RUN          Bull's Brow: a straight approach drives the body it strikes back (trait_the_run)
--   THE LABRYS       cleaves the arc in front and the arc behind
--   RECKLESS STANCE  its first turn: it hits harder and is much easier to hurt, so the first phase is a race
--   FURY             on Head Down: 1 health, unkillable for about four turns, heals half of what it deals
--   DESPERATE STRIKE double damage at 1 health -- so for the whole of the Fury window
--   THE CULLING STROKE  kills a body below the line outright, and a kill hands it the turn back
--   ADRENALINE       every blow it takes pulls its next turn sooner: mobbing it speeds it up
--   THE UNSPENT HEART   heals hard while untouched: lose it behind the walls and it mends
--
-- THE COUNTERPLAY, STATED: race the first phase while it is Reckless; spend the maze carefully, because every
-- wall it breaks is gone; stay off its straight lines, and never stand with fire or a wall behind you in one;
-- keep the wounded out of its reach; and when its head goes down, SURVIVE the Fury rather than burst it -- walls
-- and distance, so it deals little and heals little -- then finish it.
--
-- ITS HIDE takes a blow (impact +2) and a spear finds its ribs (pierce -2), on its race record -- which is a
-- record for this one body, humanoid only so that it may carry the barbarian's shelf (data/races/minotaur.lua).
-- Tier 3 and `boss`, off the execute and Charm tables like every elite of the deeps.
return {
    name = "Minotaur",
    race = "minotaur", -- a one-body record, humanoid so it may carry a shelf (data/races/minotaur.lua)
    tier = 3,
    boss = true,
    class = "fighter",
    discipline = "barbarian",
    sprite = "assets/chars/minotaur.png",
    archetype = "aggressive",
    stats = {
        health = 150, mana = 0, stamina = 36, -- the top of tier 3; Fury is its second bar
        staminaRegen = 5,
        damage = 20, magicDamage = 0,
        defense = 9, magicDefense = 5,
        movement = 4,
        speed = 3,
        skill = 7, luck = 4,
    },
    startingItems = {
        "weapon_labrys",           "utility_bulls_brow",     "utility_the_labyrinth",
        "ability_desperate_strike", "ability_reckless_stance", "ability_culling_stroke",
        "utility_adrenal_surge",   "armor_unspent_heart",    false,
    },
    drops = { "weapon_labrys", "utility_bulls_brow" },
    defaultAction = "weapon_labrys",
    signatureWeapon = "weapon_labrys",
    signatureAbility = "ability_reckless_stance",
}
