-- THE OLD SPRUCE: a boreal tree-thing of Sloth's seat ("Sloth's Bestiary", 2026-10-04, slice E).
--
--   WILL NOT BE HURRIED   it never attacks. At the end of each of its turns its roots spread one tile, and roots
--                         cannot be crossed by either side; a body that ends its turn beside it is Rooted
--                         (trait_will_not_be_hurried; models/sloth_dreamers.lua, data/walls/roots.lua)
--
-- THE COUNTERPLAY, STATED, and it is the review's: burn it, or win fast, before the roots shut the lanes -- and
-- the roots wall the enemy too. A great deal of health, an edge that bites into bark and stops, and a fire that
-- takes it like kindling.
--
-- THERE IS NO PLANT RACE, and the elemental is the nearest one: "an element with an outline around it, and what
-- it is made of is what answers it" (data/races/elemental.lua) is exactly a tree that burns. A beast is a thing
-- that hunts, which this never does; an object cannot be killed, which this can. `plant = true` puts it in the
-- grove (models/grove.lua), so the Churchyard Yew and the Nymph's kit read it as the tree it is.
--
-- A SKIRMISH BODY, NOT AN ELITE: it can be hurt by anybody and it hurts nobody. Fielded alone or with a light
-- escort (the Sleeping Wood). Tier 3's band is 81-154; high in it, because the roots are its clock, not its blows.
return {
    name = "The Old Spruce",
    race = "elemental",
    tier = 3,
    plant = true,
    unarmed = false, -- it never attacks; the roots are its whole kit
    revivable = false,
    sprite = "assets/chars/old_spruce.png",
    archetype = "defensive",
    stats = {
        health = 140, mana = 0, stamina = 0,
        damage = 0, magicDamage = 0,
        defense = 6, magicDefense = 6,
        movement = 0, -- a tree: it does not walk, its roots do
        speed = 3,
        skill = 1, luck = 0,
    },
    -- Bark turns an edge and a maul splits it (sums to zero, docs/bestiary.md). Burns badly: the weakness at the
    -- whole of tier 3's budget, because fire is the review's first answer.
    resist = { slash = 4, impact = -4, fire = -8 },
    startingItems = {
        "utility_will_not_be_hurried", false, false,
        false,                         false, false,
        false,                         false, false,
    },
    drops = { "weapon_spruce_staff" },
}
