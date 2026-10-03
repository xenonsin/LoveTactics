-- Faceless: the shapeless folk of Envy's seat, and the circle's race. Reviewed over three rounds (2026-10-01..03,
-- "Envy's Bestiary"). The first pitch was a line of blank decoys and was judged "too weak to be monsters on floor
-- 12"; the author kept the concept and asked for "extremely adaptable and capable fighters", and then for more:
-- "faceless could take the appearance and abilities of any character in the game".
--
-- A FACELESS WEARS OTHER BODIES (models/faces.lua). It carries a hand of faces dealt from the whole bestiary and,
-- at the top of each turn, puts on the one that answers the nearest of its foes (Reshape). What it is underneath
-- barely matters, which is why the line below is thin: the face brings the kit.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 slash, +1 pierce, -2 impact): no bones to speak of, so an edge and a point
-- pass through a shape that gives, and a blow that lands flat spreads all of it at once.
--
-- THE STAT LINE is movement +1: it is always arriving as something. Capped by its tier-2 line soldier.
--
-- NOT PLAYABLE. A face-thief in the company would be the copy problem with the player's own hands on it; the
-- drops lend the trick (Borrowed Face, Doppel-Step) without the race.
return {
    name = "Faceless",
    description = "Shapeless folk of the waste. Each one wears the body that best answers whoever stands nearest.",
    kind = "humanoid",
    playable = false,
    resist = {
        slash = 1,   -- an edge passes through a shape that gives...
        pierce = 1,  -- ...and so does a point...
        impact = -2, -- ...but a flat blow lands on all of it. Sums to zero.
    },
    bonus = {
        movement = 1, -- always arriving as something
    },
    grants = { "utility_faceless_blood" },
}
