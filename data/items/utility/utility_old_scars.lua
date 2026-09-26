-- OLD SCARS: the Veteran's organ (2026-09-26, "The Orcs of Wrath"). The Veterans fight was approved as "Grunts that
-- open the fight already Proven, one or two scars each"; this is how a Grunt comes to the board that way -- it opens
-- every fight Proven twice over (openingBoon), and the scars are on the token before the company engages, so it
-- can see which to kill first. A body's own, never shelved.
return {
    name = "Old Scars",
    description = "Opens each fight Proven twice over.",
    flavor = "It has done this before. The scars say how often it has done it well.",
    sprite = "assets/items/utility_old_scars.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    openingBoon = { id = "status_proven", opts = { magnitude = 2 } },
}
