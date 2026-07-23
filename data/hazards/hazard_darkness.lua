-- Darkness: ground you cannot see through. The first hazard in the game with a `sightCost`, which is
-- the whole of what it does -- no tick, no status, no damage. Standing in it is harmless. Trying to
-- shoot across it is not.
--
-- It works by widening a question the engine already asked. Line of sight sums the `sightCost` of the
-- tiles a line crosses and blocks at Combat.SIGHT_BLOCK (2); terrain has always contributed, and so
-- have walls and props. Hazard.sightCostAt adds the ground itself, so a bow's `requiresSight`, a
-- wand's, the threat-reach highlight, overwatch and the enemy AI's own targeting all go blind on this
-- cloud together, without one of them being told a hazard was involved.
--
-- `sightCost = 2` -- SIGHT_BLOCK exactly, so a single tile of it seals a line where a single tile of
-- forest (1) only halves one. That is the difference between cover and dark, and it is what makes a
-- 3x3 of this a wall that bodies walk through and arrows do not.
--
-- What it is FOR is the mage's oldest problem, which is that the Arcanum's own kit is the kit most
-- punished by an archer with a clear lane. This is the answer that does not require killing the
-- archer: put out the light between you, and the shot the enemy had is simply not there any more.
-- Both sides go blind through it, and the party's own bows too -- unsided, exactly like the Emberwand's
-- fire (docs/weapons.md): a wall you must be willing to stand behind.
--
-- Melee is untouched, and deliberately so. Nothing here stops anyone WALKING in, and a foe that closes
-- the distance is a foe the darkness has stopped protecting you from. That is the counter, it is
-- visible on the board before anyone commits, and it is the same shape as every other counter in this
-- codebase (docs/weapons.md, "reach is the gate").
return {
    name = "Darkness",
    description = "Unnatural dark: nothing can see a line across it. Walking through is untouched.",
    sprite = "assets/hazards/darkness.png",
    tags = { "dark" },
    duration = 15,           -- ~3 turns at Status.TICKS_PER_TURN, as a Fire's blaze lasts
    disposition = "neutral", -- it harms nobody, so the enemy AI has no reason to route around it
    sightCost = 2,           -- Combat.SIGHT_BLOCK: one tile of it seals a line outright
    -- No onEnter. There is nothing in here.
}
