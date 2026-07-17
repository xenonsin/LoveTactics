-- The item equivalent of the Ranged Counter reflex: a quiver that looses an arrow back at anyone who
-- shoots its bearer. A passive utility (no ability of its own) -- its whole effect is the `traits` it
-- grants (models/trait.lua). It only answers if the bearer's default weapon is ranged, so it wants to
-- sit in a bow-carrier's grid; on a swordsman it does nothing. A hunter-class piece, sold at the
-- Hunter's Lodge.
return {
    name = "Reprisal Quiver",
    description = "When shot from range, looses an arrow back. Requires a ranged weapon.",
    flavor = "The Lodge sells it to swordsmen too. They tend to find out later.",
    sprite = "assets/items/reprisal_quiver.png",
    type = "utility",
    tags = { "quiver" },
    class = "hunter",
    price = 200,
    repRank = 2,
    traits = { "trait_ranged_counter" },
}
