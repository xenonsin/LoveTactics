-- THE UNHELD: what a company carries out of a bell loft, and it is the one thing this circle has that
-- answers this circle.
--
-- LUST TAKES POSITION AND ALLEGIANCE AND NOTHING ELSE (models/descent.lua's Lust entry). The flock
-- decides where your body is, the coils decide it does not get to be anywhere else, the kiss takes your
-- tile and gives you its own. Every one of those goes through Status.blocksForcedMove, and this sets it:
-- a body wearing the Unheld is a body the entire stratum has run out of things to say to. It is the
-- rift selling you its own answer, off the one thing on the floor the floor could not move either.
--
-- WHY IT SHELVES AT THE BULWARK. "Knockback pushes a foe back and inflicts Halt where it lands, and your
-- own stance makes you immovable" (data/classes/bulwark.lua) -- the house already claims this sentence,
-- and until now the stock behind it moved other people and never quite delivered the second half. This
-- is the second half. `class` is the vendor shelf and never an equip gate (docs/classes.md): anyone can
-- carry it, and on a body whose whole plan is to be somewhere else in a moment it is a mistake.
--
-- AND IT CUTS BOTH WAYS, WHICH IS THE PRICE RATHER THAN A BUG -- the piece is a genuine decision and not
-- a strict upgrade. The same flag that refuses a harpy's talons refuses your own party: no ally may drag
-- the bearer out of a fire, no Gaff Line or Pull repositions it, a rescue cannot shift it off the tile
-- it went down on, and several of the bearer's OWN leaps stop working (Combat.charge reads the flag of
-- the user as well as of the target). Root's header argues this at length and it is the same argument:
-- a body that cannot be moved cannot be moved by its friends either.
--
-- NOT CURABLE AND NOT A WINDOW. status_unheld carries no `debuff` flag and 9999 ticks, so it is a stance
-- the bearer lives in for the whole fight rather than a ward somebody spends a turn opening. That is
-- what makes it worth a grid cell against a circle, and what makes it a liability in a fight where the
-- party needed to pick the bearer up.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Unheld",
    description = "You cannot be moved: no shove, drag, throw or charge shifts you.",
    flavor = "Whatever it is made of, a hand closes on it and comes back with the hand.",
    sprite = "assets/items/the_unheld.png",
    type = "utility",
    tags = { "charm", "wind" },
    class = "bulwark",
    unlockLevel = 5,
    traits = { "trait_nothing_to_hold" },
}
