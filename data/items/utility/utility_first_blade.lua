-- The Peerless's own blade-hand, and the vessel Single Combat rides in.
--
-- A body's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua) -- and an Elite is a signature relic and a rule list that reads rather than a health
-- pool with a sword (tests/bestiary_spec.lua). This is that relic.
--
-- Natural kit: no class, no price, noSteal. The Peerless is humanoid and could carry shelf gear, but
-- nothing about it is lootable -- it is the last of a house that has been dead four hundred years, and
-- what it holds is not for sale.
return {
    name = "First Blade",
    description = "Gains damage and defense while exactly one foe stands beside it.",
    flavor = "It has never been second at anything and does not intend to begin in a corridor.",
    sprite = "assets/items/first_blade.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_single_combat" },
}
