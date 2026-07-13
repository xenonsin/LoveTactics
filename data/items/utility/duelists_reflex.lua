-- The item equivalent of the Dodge reflex: a duelist's trained instinct that slips a blow on its own.
-- A passive utility (no ability of its own) -- its whole effect is the `traits` it grants
-- (models/trait.lua). While it sits in the bearer's grid they automatically evade the next physical
-- attack, then the reflex recharges before it can save them again; a spell it cannot dodge. Kin to the
-- Reprisal Quiver, which packages the Ranged Counter the same way. A fighter-class piece, sold at the
-- Colosseum.
return {
    name = "Duelist's Reflex",
    description = "Automatically evade a physical attack now and then. Magic still lands.",
    sprite = "assets/items/duelists_reflex.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 240,
    repRank = 2,
    traits = { "dodge" },
}
