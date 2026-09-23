-- THE UPDRAUGHT: what a company carries out of the flock, and it is the flock's own gust.
--
-- A harpy spends its whole fight deciding where you are standing -- the talons haul you in, the gust
-- drives you off, and neither blow is worth much on its own (data/characters/character_harpy.lua).
-- This is the second half of that, handed over: every melee blow the bearer lands drives what it hit
-- back a tile. See data/traits/trait_stooping_blow.lua for why it is melee only and what that costs.
--
-- THE RIFT SELLS YOU THE TRICK, which is the ordering the Barrow Lord's Marrowlight argues in full: a
-- rule like this is a strange thing to be handed cold at a counter and an ordinary thing to be handed
-- by the corpse of the thing that spent a fight doing it to you.
--
-- `class` IS THE VENDOR SHELF AND NEVER AN EQUIP GATE (docs/classes.md). The Skirmisher is where the
-- shove is written down, not who is allowed to swing it -- anyone can carry this, and on a body that
-- was not going to move anyway it is a harder bargain, which is the point.
--
-- FOUND IN THE RIFT, NOT DEALT OVER A COUNTER (docs/shelf.md): no `price`, so a counter stocks it only
-- once the class has climbed to its rung.
return {
    name = "The Updraught",
    description = "Your melee blows drive what they hit back a tile.",
    flavor = "They do not take you anywhere. They only ever object, very hard, to where you were.",
    sprite = "assets/items/the_updraught.png",
    type = "utility",
    tags = { "charm", "wind" },
    class = "skirmisher",
    unlockLevel = 8,
    traits = { "trait_stooping_blow" },
}
