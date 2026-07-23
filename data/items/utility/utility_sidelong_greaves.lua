-- Sidelong Greaves: the wearer walks through people. Not past them, not around them -- through.
--
-- A REAL GRID MECHANIC rather than a number, and the only new kind of movement this catalog has added.
-- An enemy body bars a tile outright for everybody else in the game (see moveGraph in
-- models/combat.lua): that single rule is what makes a shield wall in a corridor work, what makes a
-- doorway hold, and what makes the knight's whole shelf mean anything. These greaves are the answer to
-- it, and until now there was none.
--
-- WHAT IT DOES NOT BUY is the ability to share a square: an occupied tile is still not a place to
-- STOP (Combat.reachable drops every occupied node whoever is standing on it). So the wearer cannot
-- sit inside the enemy line -- only pass through it and come out the far side, which is precisely the
-- rogue's and the skirmisher's job and precisely what a wall of bodies existed to prevent.
--
-- It occupies the same `moveBehavior` slot the Blink stone does, and is therefore mutually exclusive
-- with it by construction -- both answer "what is this unit's movement", and a grid holding both is a
-- loadout built badly rather than a case anybody has to resolve. That is the right relationship: blink
-- ignores the ground and costs mana per jump; this ignores BODIES and costs nothing at all, forever.
--
-- Which is why it is a permanent property rather than a toggle. There is no downside to phasing and
-- no decision in switching it on, so making it a stance would have been a button the player presses
-- once at the start of every battle -- and this codebase has enough of those.
return {
    name = "Sidelong Greaves",
    description = "Its wearer walks straight through enemy bodies, though never stops on one.",
    flavor = "The Undercroft's cobbler asks no questions and offers no fittings. They fit anyone.",
    sprite = "assets/items/utility_sidelong_greaves.png",
    type = "utility",
    tags = { "boots" },
    class = "rogue",
    price = 400,
    repRank = 4,
    -- The `moveBehavior` contract (see data/items/ability/ability_blink.lua, which carries the other
    -- mode): an item that changes how a VERB behaves rather than adding an action. It feeds no
    -- initiative and never sits in the ability cycle.
    moveBehavior = { mode = "phase" },
    bonus = { movement = { 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3 } },
}
