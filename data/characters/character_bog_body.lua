-- BOG BODY: the line's soldier, on Sloth's approach ("Sloth's Bestiary", 2026-10-04, slice C). One of the
-- Bog-Bound -- the mummies and bog bodies laid in the frozen mire -- holding a peat-black spear. Reach 2. They
-- rise in threes across the lanes.
--
--   PAST FEELING     a blow of 8 damage or less does nothing; anything heavier lands in full
--   THE MIRE HOLDS   a foe that starts its turn beside it pays 2 movement to step away
--                    (both on utility_bog_bound; models/sloth_bog.lua)
--
-- THE LESSON, STATED: only heavy blows count, and do not end a turn beside one unless you mean to stay. The
-- spear's two tiles are why standing one off is not safe either.
--
-- Undead, so it takes holy the harder. Peat-tanned hide turns an edge and a point a little, and a club breaks
-- it -- the physical three sum to zero. Slow: a body that has lain a thousand years is in no hurry.
return {
    name = "Bog Body",
    race = "undead",
    tier = 2,
    sprite = "assets/chars/bog_body.png",
    stats = {
        health = 56, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 10, magicDamage = 0,
        defense = 5, magicDefense = 3,
        movement = 3,
        speed = 3,
        skill = 4, luck = 2,
    },
    resist = { slash = 1, pierce = 1, impact = -2, holy = -3 },
    startingItems = {
        "weapon_bog_spear", "utility_bog_bound", false,
        false,              false,               false,
        false,              false,               false,
    },
    drops = { "weapon_peat_black_spear" },
    defaultAction = "weapon_bog_spear",
    archetype = "aggressive",
}
