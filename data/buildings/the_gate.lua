-- Building blueprint. THE GATE: the mouth of the descent, and the city's front door.
--
-- WHAT THE PLAYER IS DOING HERE. The prologue ends by walking into the capital with Rowan sworn beside
-- you, and the guard scene plays over the city. What used to happen next was the Quest Board: the seven
-- houses' work, forty days, a deadline. What happens now is that a sponsor is at the gate hiring able
-- bodies to go down (data/conversations/prologue/conversation_prologue_sponsor.lua), and the hole in
-- the ground is the game.
--
-- SO THIS CARD REPLACES THE QUEST BOARD, in its slot and in its role. The board's data is still on disk
-- and every quest with it -- nothing was deleted -- but models/building.lua retires it from the city, so
-- there is one door out of the capital and it goes down. That is the campaign being PARKED rather than
-- cut: it costs one line to bring back.
--
-- `state` rather than `panel`: the gate is a whole screen (states/gate.lua -- the inn, the store, the
-- hiring hall and the stair), not a pop-up over the city. The Dueling Grounds already opens a state this
-- way, so the hub needed nothing new.
--
-- `unlockPrestige = 1` because it is the first thing there is. A city whose only door were locked would
-- be a city with nothing in it.
return {
    name = "The Gate",
    order = 1,
    x = 40,
    y = 120,
    w = 270,
    h = 130,
    state = "gate",
    sprite = "assets/hub/the_gate.png", -- falls back to its name plate until art lands
    description = "A stair down, a lamp over it, and a queue of people who need the work.",
    unlockPrestige = 1,
}
