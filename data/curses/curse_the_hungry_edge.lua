-- THE HUNGRY EDGE: it opens the bearer before it opens anything else.
--
-- AN OPENING BOON, INVERTED (`openingBoon`, drained onto the bearer by states/battle.lua at the bell).
-- Four relics used to dress the front line in Regen, Haste, Heroism or a barrier at the opening bell and
-- are items now; this is that same seam pointed the other way, and it is the cheapest possible way to
-- make a hex felt in EVERY fight rather than in a stat line the player stops reading.
--
-- IT COSTS THE OPENING TURN, NOT THE FIGHT. Bleed is cleansable and a Cure away, so what this actually
-- charges is the party's first cleanse, every fight, for as long as the piece is carried -- a tax on the
-- action economy rather than on the health bar. That is the right size for a floor-four find:
-- irritating, answerable, and never the thing that kills you.
return {
    name = "The Hungry Edge",
    description = "The bearer opens every fight bleeding, and cannot put the piece down.",
    binds = true,
    depth = 4,
    fee = 160,
    openingBoon = { id = "status_bleed" },
}
