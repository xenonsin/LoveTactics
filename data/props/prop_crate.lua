-- A supply crate: the inert prop, and the reason `props` is a category rather than a synonym for
-- "barrel". It does nothing at all -- it is a body-sized box standing on a tile, which makes it cover
-- to path around, a lane to close, and something to heave at somebody. Breaking it just breaks it.
--
-- It earns its place by what it does to the OTHER props: a board with only barrels teaches the party to
-- shoot every object on sight, and a board with crates among them makes "which of those is a bomb?" a
-- question worth asking. It also stands next to barrels well -- a barrel's blast splinters it, so a
-- crate is a visible marker of what the blast reached.
--
-- Tougher than a barrel (it has no trigger to spend, so its HP is the whole of it) and it screens sight
-- at 1, which is soft cover: a single crate lowers a line without breaking it, two stacked block it --
-- the same rule forest terrain follows (Arena.TILE_PROPS).
return {
    name = "Supply Crate",
    description = "A heavy crate. Cover to hide behind, and a weight to throw.",
    sprite = "assets/props/crate.png", -- placeholder until its own art exists
    color = { 0.55, 0.42, 0.24 }, -- pine, for the renderer's fallback block
    health = 10,
    blocksMove = true,
    sightCost = 1, -- soft cover: it lowers a line of sight without blocking it outright
    tags = { "prop", "flammable" },
    -- Which biomes stack their supplies in the open: a forest camp and a castle's yard, never the
    -- underworld -- nothing down there ships anything.
    biomes = { forest = 4, castle = 3 },
}
