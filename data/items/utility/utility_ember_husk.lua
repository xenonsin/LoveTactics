-- The husk an ember-spit and a cinder-kin are left as, and the vessel Cinderfall rides in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua) -- so the ground the volcanic circle's chaff leaves behind is authored here.
--
-- Shared by both the swarm and the line, deliberately. The rule is a property of the STRATUM rather
-- than of one body: things that die on this floor catch fire, and a player should learn that from the
-- cheapest thing on the board and find it still true of the expensive ones.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Ember Husk",
    description = "Leaves fire on the tile it falls on.",
    flavor = "Not quite out. It never is, down here.",
    sprite = "assets/items/ember_husk.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_cinderfall" },
}
