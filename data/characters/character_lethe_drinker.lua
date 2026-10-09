-- THE LETHE-DRINKER, the Crown's ordinary traffic (approved 2026-10-09, "The Crown's Bestiary", slice E). Theme:
-- Damnation -- a body the dead drink from to forget.
--
-- IT DOES NOTHING TO YOU DIRECTLY, and the blueprint says so in two fields: no weapon in the grid and
-- `unarmed = false`, so there is not even a fist. All it carries is the river (utility_lethe_haze): a foe within
-- 2 cannot use the ability it used last turn. The ghosts beside it do the hurting; it makes the company's best
-- answer to them a once-a-turn thing.
--
-- UNDEAD, because it is a dead thing -- and so it wears Grave-Cold like every one of them, which a Hungry Ghost's
-- meal does not care about (the eaten heal lands as a drink). How you beat it: rotate your abilities while you
-- are near it, step out of the haze to repeat your best one, or kill it first.
--
-- It drops the Cup of Lethe.
return {
    name = "Lethe-Drinker",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/lethe_drinker.png",
    archetype = "aggressive",
    unarmed = false,
    stats = {
        health = 52, mana = 0, stamina = 20,
        staminaRegen = 3,
        damage = 0, magicDamage = 0, -- the absence of the field: it never strikes
        defense = 4, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 0, luck = 4,
    },
    -- Waterlogged: a point turns aside, a hammer splits it. The physical lines sum to zero (docs/bestiary.md).
    resist = { pierce = 2, impact = -2, holy = -3 },
    startingItems = {
        "utility_lethe_haze", false, false,
        false,                false, false,
        false,                false, false,
    },
    drops = { "utility_cup_of_lethe" },
}
