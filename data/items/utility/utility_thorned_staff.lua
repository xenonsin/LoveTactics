-- THORNED STAFF: the Pale Crone's trophy (data/characters/character_pale_crone.lua; "Envy's Bestiary", round 4).
-- The body's own rule pointed outward and given a reach: once a round, a foe healed or blessed within 3 is leapt on
-- and struck (trait_grief_at_fortune, `reach = 3`). A Skirmisher's, because it is a leap that punishes a backline.
return {
    name = "Thorned Staff",
    description = "Once a round, when a foe within 3 is healed or blessed, leap beside it and strike.",
    flavor = "Somebody else's good day is a thing it can find from across a field.",
    sprite = "assets/items/utility_thorned_staff.png",
    type = "utility",
    tags = { "charm" },
    class = "skirmisher",
    unlockLevel = 11,
    unstocked = true,
    traits = { "trait_grief_at_fortune" },
    traitParams = { reach = 3 },
}
