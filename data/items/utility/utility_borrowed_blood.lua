-- BORROWED BLOOD: the vessel the Abbess's drinking rides in -- the blood she gave away, coming back.
--
-- A creature's rule lives on an ITEM in its grid (models/trait.lua). See
-- data/traits/trait_borrowed_blood.lua for why it is a flat sip and why it only ever pays out from a
-- body she is holding herself.
--
-- NOT DROPPED, and the reason is that it is unplayable rather than that it is precious: a rule that
-- pays out when a foe YOU charmed lands a blow is a blank cell for every company that does not carry
-- Charm, and a thin one even for the company that does. What the rift hands over off this line is the
-- kiss and the congregation, which are rules a player can build around.
--
-- A creature's kit: no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Borrowed Blood",
    description = "Heals you whenever a foe you have Charmed strikes.",
    flavor = "The Cathedral calls it a gift and means it. She calls it a loan and means that.",
    sprite = "assets/items/borrowed_blood.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "dark" },
    noSteal = true,
    traits = { "trait_borrowed_blood" },
}
