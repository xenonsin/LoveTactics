-- THE HOMUNCULUS: one of Envy's one-off families, on the waste's seat ("Envy's Bestiary", 2026-10-03, slice C). The
-- author's note on the first pitch: "homunculi are creations of alchemists, think of full metal alchemist". A
-- made being with a red stone for a heart, holding several lives -- the alchemist's house is Envy's vendor, and
-- this is the thing that house would most like to have made.
--
--   RED STONE    it opens with 3 Red Stone; a killing blow consumes one instead, and it stands back up at full
--                health at the start of its next turn. At 0 it dies for good (trait_red_stone)
--   THE HEART    while it holds any, it heals a tenth of its health each turn
--
-- THE COUNTERPLAY, STATED: kill it three times, or end it in one round so it never gets up -- a fallen one lies at 1
-- health until its turn comes. Unclosing stops both the healing and the getting up.
--
-- NOT character_homunculus, which is the alchemist's own summon and keeps its name and its file. A construct, made
-- of alchemical clay poured round the stone: a blade finds the seam, a point sinks in and stops.
return {
    name = "Homunculus",
    race = "construct",
    tier = 3,
    sprite = "assets/chars/red_homunculus.png",
    stats = {
        health = 82, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 4, magicDefense = 4,
        movement = 4,
        speed = 4,
        skill = 6, luck = 2,
    },
    resist = { pierce = 2, slash = -2, acid = 2 },
    startingItems = {
        false,                     false,                     false,
        "weapon_homunculus_fists", "utility_red_stone_heart", false,
        false,                     false,                     false,
    },
    defaultAction = "weapon_homunculus_fists",
    -- ITS OWN PIECE (docs/drops.md): the stone, turned to the bearer's use.
    drops = { "utility_stone_heart" },
    archetype = "aggressive",
}
