-- THE TOWER-GIANT: one of Pride's one-off elites, on the spire's seat ("Pride's Bestiary", 2026-09-30). Babel
-- with legs: a tower that learned to walk and is still building itself higher, one course a turn.
--
--   AMBITION        a stack of Ambition at the end of each of its turns (trait_ambition)
--   THE PROUD FALL  when it falls, it crashes on every tile within 1 + floor(Ambition / 3) for 6 impact damage
--                   per stack, on every body there (trait_the_proud_fall; PrideElites.crashOf)
--
-- THE COUNTERPLAY, STATED: the proud fall hardest. Kill it early, while the fall is small -- or, once it is
-- not, clear the ground before the last blow and land it from outside the ring. The badge's count is the
-- reach and the weight of the fall at every moment, so the decision is on the board the whole fight.
--
-- A CONSTRUCT: it is masonry that walks, which is also what keeps its kit to natural weapons only. Fitted stone
-- turns an edge and a hammer breaks it. ALONE (encounter_pride_the_tower_giant): anything beside it would be
-- standing under it. Tier 3 and `boss`.
return {
    name = "Tower-Giant",
    race = "construct",
    tier = 3,
    boss = true,
    sprite = "assets/chars/tower_giant.png",
    stats = {
        health = 150, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 17, magicDamage = 0,
        defense = 10, magicDefense = 5,
        movement = 3,
        speed = 2,
        skill = 5, luck = 0,
    },
    resist = { slash = 3, impact = -3 },
    startingItems = {
        false,                 false,                          false,
        "weapon_masonry_fist", "utility_the_unfinished_tower", false,
        false,                 false,                          false,
    },
    defaultAction = "weapon_masonry_fist",
    -- ITS OWN PIECE (docs/drops.md): its ambition, on a maul.
    drops = { "weapon_babel_maul" },
    archetype = "aggressive",
}
