-- Building blueprint. THE RIFT: the mouth of the descent, and the city's front door.
--
-- IT WAS CALLED THE GATE, and the `id` still is -- ids are internal and renaming this one would touch
-- states/gate.lua, models/gate.lua, every spec that names a building and nothing the player can see.
-- What changed is the NAME, and it changed because a gate is a thing a city builds and this is a thing
-- that happened to it. There are two tears and they are the same wound: this is the one you go down
-- into, and the Crossing (data/buildings/hiring_hall.lua) is the small one above ground that people
-- come up out of. This one wears the name -- it is the older, the larger, and the one the whole city
-- grew up against -- and the other is named for what is done at it, so the two never trade places.
--
-- THE PLAYER IS TOLD THE NAME ONCE, by the sponsor, in the line that exists to do exactly that
-- ("Everyone calls it the Rift" -- conversation_prologue_sponsor). A place the fiction never names is
-- a place the player calls by whatever the card says, so that line and this field must always agree.
--
-- WHAT THE PLAYER IS DOING HERE. The prologue ends by walking into the capital with Rowan sworn beside
-- you, and the guard scene plays over the city. What used to happen next was the Quest Board: the seven
-- houses' work, forty days, a deadline. What happens now is that a sponsor is at the gate hiring able
-- bodies to go down (data/conversations/prologue/conversation_prologue_sponsor.lua), and the tear in
-- the ground is the game.
--
-- SO THIS CARD REPLACES THE QUEST BOARD, in its slot and in its role. The board's data is still on disk
-- and every quest with it -- nothing was deleted -- but models/building.lua retires it from the city, so
-- there is one door out of the capital and it goes down. That is the campaign being PARKED rather than
-- cut: it costs one line to bring back.
--
-- `state` rather than `panel`: the rift is a whole screen (states/gate.lua -- the inn, the store, the
-- stair down), not a pop-up over the city. The Dueling Grounds already opens a state this
-- way, so the hub needed nothing new.
--
-- `unlockPrestige = 1` because it is the first thing there is. A city whose only door were locked would
-- be a city with nothing in it.
--
-- IT SITS IN THE MIDDLE AND IT IS DRAWN LARGER, which is the one thing on this board that is not a
-- lattice position (models/building.lua's GRID). Everything else in the city is something you do BEFORE
-- going down or BECAUSE you came back up -- hire, sleep, arm, eat, buy, spar -- so a row of equal plates
-- with the stair first among them says the wrong thing. Around it, they read as what they are: a town
-- that grew up against a hole in the ground.
return {
    name = "The Rift",
    order = 1,
    x = 490,
    y = 280,
    w = 300,
    h = 170,
    state = "gate",
    sprite = "assets/hub/the_gate.png", -- falls back to its name plate until art lands
    description = "A stair down, a lamp over it, and a queue of people who need the work.",
    unlockPrestige = 1,
}
