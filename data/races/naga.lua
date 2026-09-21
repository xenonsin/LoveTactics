-- Naga: serpent-folk, and the first race authored after the axis existed to hold one.
--
-- WHAT THEY ARE, in one table: they shrug water, they die to lightning, scale turns a blade and takes a
-- club, and a spearpoint finds the gaps between the plates. Said once here rather than four times
-- across data/characters/, which is the whole argument for the axis -- four blueprints stating one fact
-- are four blueprints that can drift apart.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 slash, +1 impact, -2 pierce), which is the innate contract held:
-- mitigation here is subtractive, so a hide that turned every weapon aside would be a buff rather than
-- a redistribution, and turning the blade costs them the point. Every value sits inside the rung-1
-- budget (Balance.INNATE_BUDGET: 2, doubled for a weakness) because the Shoalkin is rung 1 and wears
-- this table unchanged -- a race is written to the LOWEST rung that wears it, or its own chaff is over
-- budget the day it is authored.
--
-- THE LIGHTNING LINE IS LOAD-BEARING IN TWO DIRECTIONS and is the reason to read this file twice. It is
-- why the Tidecaller's own trick is the answer to the Tidecaller: a fen board is mire, shallows and
-- deep water, all three conducting, so the most dangerous ground in the game for a naga is the ground
-- it chose to fight on. A faction whose plan is "stand in the channel" has to have a reason that is a
-- bad plan sometimes, and this is it.
--
-- THE STAT LINE IS WHAT PRICES THE SWIM. Free passage through water and over ground nobody else can
-- cross is a large gift, and the flying tag taught this the hard way -- it paid nothing for the ground
-- and collected the forest's cover on top, so a tag sold as a trade was pure upside until somebody
-- noticed (docs/terrain.md). Movement -1 is the bill: a naga on dry stone is slower than the men it is
-- fighting, and it knows, which is why every naga fight is fought where they chose. Speed +1 is the
-- other half of the same body -- slow to arrive, quick once it has.
--
-- THE COILS ARE GRANTED rather than authored into four grids. They are bound and unstealable, so
-- swimming never comes off a naga's corpse -- what the player takes off the Undertow instead is the
-- Gillscale Wrap, a MADE thing, which is the honest split between an organ and a piece of kit.
return {
    name = "Naga",
    description = "Serpent-folk of the fen. They hold the water, and the water is what kills them.",
    kind = "humanoid",
    tags = { "swim" },
    resist = {
        water = 2,       -- their own element runs off them
        lightning = -4,  -- and it is the thing they die to (a weakness may go twice as deep)
        slash = 1,       -- scale turns a blade...
        impact = 1,      -- ...and takes a club...
        pierce = -2,     -- ...and a spearpoint finds the gaps between the plates. Sums to zero.
    },
    bonus = {
        movement = -1,   -- dragging itself over dry stone: the bill for the lane
        speed = 1,       -- and striking before you are ready, once it arrives
    },
    grants = { "utility_naga_coils" },
}
