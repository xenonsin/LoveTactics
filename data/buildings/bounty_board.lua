-- Building blueprint. THE BOUNTY BOARD: the city's other door out, and the one that goes across
-- rather than down.
--
-- WHAT IT IS. The seven houses post work here. A row is a BOUNTY -- a ground, a tier, a body standing
-- at the end of it, and the one piece that body gives up -- and taking it spends the day on that ground
-- (models/bounty.lua). Where the Rift asks how deep you are willing to go, this asks what you are
-- willing to go and get, which is a different question and the reason both cards can stand in one city.
--
-- IT IS NOT THE OLD QUEST BOARD, though it stands in the same tradition and its panel is descended from
-- that one. The board it replaced listed GROUNDS and put every piece of work posted there on the map at
-- once; a row here is one posting with one end, because a bounty that named four bosses could not name
-- the piece you were going for -- and the piece is the whole of why this exists.
--
-- THE MIDDLE OF THE PLAZA, AND DRAWN LARGER, which is the one position on this board that is not a
-- lattice slot (models/building.lua's GRID).
--
-- It stood in the empty slot ABOVE this one for a pass, while the Rift still held the middle. The Rift
-- has left the city (states/menu.lua's debug column) and the board takes its place -- the slot and the
-- role together, which is exactly what the Rift itself did to the Quest Board before it.
--
-- WHY THE MIDDLE MATTERS. Everything else in the city is something you do BEFORE going out or BECAUSE
-- you came back -- arm, eat, buy, forge, spar -- so a row of equal plates with the front door among
-- them says the wrong thing. Around a larger centre they read as what they are: a town arranged around
-- the work that pays for it.
--
-- `unlockPrestige = 1` for the same reason the Rift carries it: a city whose only doors were locked
-- would be a city with nothing in it.
return {
    name = "Bounty Board",
    order = 1,
    x = 490,
    y = 280,
    w = 300,
    h = 170,
    panel = "bounty_board",
    sprite = "assets/hub/bounty_board.png", -- falls back to its name plate until art lands
    description = "Posted work, a day's walk out: a ground, a body at the end of it, and what it owes.",
    unlockPrestige = 1,
}
