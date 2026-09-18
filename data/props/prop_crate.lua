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
--
-- AND IT IS FULL OF SOMETHING, which is the one thing it does that a rock does not. Breaking one banks
-- a craft stock onto the fight (models/prop.lua's creditSalvage), paid out with the rest of the takings
-- when the fight is WON. That is a decision rather than a gift, and the 10 HP above is what prices it:
-- prying the lid off costs the better part of a turn somebody was going to spend on a demon, so a crate
-- is worth walking to on a board you are winning and worth leaving shut on one you are not.
--
-- It also sharpens the question this prop exists to ask. A board of barrels teaches "shoot every object
-- on sight"; a board of barrels and crates asks "which of those is a bomb?" -- and now both answers pay
-- something, so the shot is a gamble with two live outcomes instead of a guess with one dud.
return {
    name = "Supply Crate",
    description = "A heavy crate. Cover to hide behind, a weight to throw, and supplies for whoever gets it open.",
    sprite = "assets/props/crate.png", -- placeholder until its own art exists
    color = { 0.55, 0.42, 0.24 }, -- pine, for the renderer's fallback block
    health = 10,
    blocksMove = true,
    sightCost = 1, -- soft cover: it lowers a line of sight without blocking it outright
    salvage = 1,   -- one craft stock toward the win, capped per fight at Prop.SALVAGE_CAP
    tags = { "prop", "flammable" },
    -- Which biomes stack their supplies in the open: a forest camp and a castle's yard, never the
    -- underworld -- nothing down there ships anything. The colosseum is the heaviest of the lot,
    -- because a crate is what the house sets out for the card and the crowd came to watch it used.
    biomes = { colosseum = 5, forest = 4, castle = 3, desert = 3, tundra = 3, swamp = 1 },
}
