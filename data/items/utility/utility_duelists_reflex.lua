-- The item equivalent of the Dodge reflex: a duelist's trained instinct that slips a blow on its own.
-- A passive utility (no ability of its own) -- its whole effect is the `traits` it grants
-- (models/trait.lua). While it sits in the bearer's grid they automatically evade the next physical
-- attack, then the reflex cools down before it can save them again; a spell it cannot dodge. Kin to the
-- Reprisal Quiver, which packages the Ranged Counter the same way. A fighter-class piece, sold at the
-- Colosseum.
return {
    name = "Duelist's Reflex",
    description = "On a physical attack: deflect it, then go on cooldown.",
    flavor = "Trained instinct, sold by the yard. The Colosseum has never been short of duelists to copy.",
    sprite = "assets/items/duelists_reflex.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    unlockQuests = 0,
    dropTier = 5,
    traits = { "trait_dodge" },
    -- a deflection is guard, arriving late
    bonus = { defense = 2 },
}
