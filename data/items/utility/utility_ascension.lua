-- ASCENSION: the Archon Duke's trophy (data/characters/character_archon_duke.lua; "The Crown's Bestiary", slice A,
-- 2026-10-09). The Duke Ascends on its court's wisps; the bearer Ascends on the foes it downs. Each is a stack, and at
-- the third it Ascends for the rest of the fight: +6 Damage and +2 Movement (trait_ascension). A Champion's, because
-- a crowd that has watched three fall is a crowd that is yours.
return {
    name = "Ascension",
    description = "Each foe you down gives a stack. At 3 you Ascend for the fight: +6 damage and +2 movement.",
    flavor = "The Duke needed three of its own. You will make do with three of anybody's.",
    sprite = "assets/items/utility_ascension.png",
    type = "utility",
    tags = { "charm" },
    class = "champion",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_ascension" },
}
