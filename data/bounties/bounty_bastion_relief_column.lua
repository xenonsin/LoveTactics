-- The Bastion's opening posting, and the first bounty in the game.
--
-- THIS IS A POSTING OF WORK THAT ALREADY EXISTED. `quest_bastion_slot_01` owns the map, the climb, the
-- two wagons, the Breachward at the gate and both scenes; this file owns what a BOARD has to say about
-- it before the player commits -- where it is, how hard, who is standing at the end, and what that body
-- gives up. See models/bounty.lua for why the two are separate files.
--
-- WHY THE HORN IS THE PIECE. The bounty names ONE item out of the three the work pays, and it has to
-- be the one that argues for the trip. The Relief Horn swaps a body with the ally beside it and braces
-- them where they land -- the relief column written as a thing you can hold, from the quest whose whole
-- shape is that the man behind you is also holding a pike. A player who reads the board and takes this
-- because they want the horn has understood the loop in one gesture, which is the entire job of phase 0.
--
-- The other two rewards are unchanged and still pay: the piece is a headline, not a narrowing
-- (models/bounty.lua's questFor).
--
-- TIER 1, so `floorLevel` lands at 1 and the fight is exactly what the blueprint was balanced as. The
-- climb escalates on its own -- five authored encounters thickening up the mountain -- so nothing here
-- needs to lift it.
--
-- NO `requires`, because it is the bottom of the Bastion's ladder. Everything above it names this one,
-- which is the whole of the rank gate: the ladder is what opens the next rung, and there are no seals
-- (see models/bounty.lua's header).
--
-- STANDING, which is the other half of being an opener: always on the board, never spent. It is the
-- floor under the Bastion's whole economy -- a company that burns every deeper posting it holds can
-- always walk back here -- and it is why exactly one posting per house carries the flag.
return {
    name = "The Relief Column",
    standing = true,
    description = "Highwatch is besieged and twelve days without supply. Get the column up the mountain.",

    -- The house that posted it. Sets the material tagging through Vendor.get(...).class.
    sponsor = "bastion",

    -- WHERE. A mountain post in a hard winter, which is the ground the blueprint already authored
    -- itself for -- named here anyway, because the ground is a bounty's own field and a posting that
    -- inherited it silently would be one that could not be moved.
    ground = "tundra",

    tier = 1,

    -- The work: its map, its fight, its scenes.
    quest = "quest_bastion_slot_01",

    -- WHO IS AT THE END. `character_siege_breaker`, and the name is quoted rather than derived so the
    -- board can say it before the map has been generated.
    bossName = "The Breachward",

    -- WHAT SHE GIVES UP. The named piece -- the thing this trip is for.
    piece = "utility_relief_horn",
}
