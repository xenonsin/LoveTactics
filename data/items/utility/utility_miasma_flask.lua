-- The Miasma Flask: an unstoppered jar of something the Crucible will not name, worn at the belt. It
-- gases everything standing next to its wearer, every turn, forever -- including the wearer.
--
-- GROUND THAT WALKS (Combat.layIncense), which is the censer family's mechanic borrowed off the
-- Cathedral by the class that borrows everything. The comparison is the item: a censer's smoke is a
-- blessing its carrier stands in the middle of, and this is the same shape with the sign flipped -- a
-- poison its carrier also stands in the middle of, because there was never a way to hold an open jar
-- and not breathe it.
--
-- IT POISONS ITS WEARER TOO, and that is not a drawback bolted on for balance -- it is the whole item.
-- Poison is a clock, and a clock running on both sides is a bet that you can close the distance and
-- finish before it matters. An alchemist who wears this and then plays carefully has wasted it; one
-- who wears it and walks into the middle of three bodies has started a race they intend to win.
--
-- Which makes it the closest the envy shelf gets to a wrath item, and the pairing that makes it work
-- is not on this file: something that mends. A Vampiric Strike, a Red Thirst, a priest, an Unspent
-- Heart -- the flask is a build's engine rather than a slot's payload, and on its own it is a slow
-- way to lose.
--
-- No active ability at all, and no cost. It is not used; it is worn, and it runs.
return {
    name = "The Miasma Flask",
    description = "Gasses everything adjacent every turn, its wearer included.",
    flavor = "The Crucible's seal on it reads DO NOT OPEN. Somebody has scratched out the NOT, twice.",
    sprite = "assets/items/utility_miasma_flask.png",
    type = "utility",
    tags = { "poison" },
    class = "alchemist",
    price = 300,
    repRank = 3,
    -- The `incense` contract (see Combat.layIncense): a hazard, a radius, and a magnitude, laid around
    -- the bearer on every move and every rebase, and lifted from wherever they were. Radius 1, so it
    -- is genuinely adjacent-only -- a wider cloud would make this a zoning item, and it is meant to be
    -- an engine for closing rather than a reason to stay away.
    incense = { hazard = "hazard_choking", radius = 1, amount = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
}
