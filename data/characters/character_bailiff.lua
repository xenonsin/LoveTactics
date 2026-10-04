-- THE BAILIFF: a Tollkeeper of Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice F), and the line's Barrier.
--
--   THE BARRIER  it braces at the end of every turn, and its brace covers every Tollkeeper beside it -- Braced until
--                its next turn -- so a line of them is a gate (utility_the_barrier, models/toll.lua)
--   EXIT FEE     as every Tollkeeper (utility_exit_fee), and an impact blow breaks its brace -- on the Bailiff, every
--                brace it lent comes down with it
--
-- THE COUNTERPLAY, STATED: go around the gate, or break the brace with impact.
--
-- A demon: holy bites, and the bar burns. The hide turns an edge and gives under a hammer, which is the counter
-- written into the body as well as the rule.
return {
    name = "Bailiff",
    race = "demon",
    tier = 3,
    sprite = "assets/chars/bailiff.png",
    stats = {
        health = 88, mana = 0, stamina = 26,
        staminaRegen = 3,
        damage = 11, magicDamage = 0,
        defense = 7, magicDefense = 4,
        movement = 3,
        speed = 3,
        skill = 5, luck = 3,
    },
    resist = { slash = 3, pierce = 1, impact = -4 },
    startingItems = {
        false,             false,                 false,
        "weapon_gate_bar", "utility_the_barrier", "utility_exit_fee",
        false,             false,                 false,
    },
    defaultAction = "weapon_gate_bar",
    -- ITS OWN PIECE (docs/drops.md): the barrier, on a Defend.
    drops = { "armor_bailiffs_bar" },
    archetype = "aggressive",
}
