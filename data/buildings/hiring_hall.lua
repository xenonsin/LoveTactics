-- Building blueprint. THE HIRING HALL: where a company is made.
--
-- The player is not on the board. Every body that walks down the stair is somebody hired here or found
-- on a floor, so this is the door the whole mode opens on -- a fresh save arrives at a city where this
-- is the only card that does anything, because there is nobody to sleep, shop or descend with yet.
--
-- WIZARDRY'S TAVERN, doing the job it does there: you keep no roster of your own creations, so instead
-- of forming a party from characters you rolled, you take on people who will go. The slate is the same
-- authored one the floors offer (models/descent_recruit.lua), which is what makes the town and the road
-- hand over the same kind of body by the same rules -- a hire is not a better class of recruit, it is
-- the same recruit met above ground.
--
-- IT WAS A ROW ON THE GATE SCREEN. See data/buildings/the_inn.lua for why neither of these is.
return {
    name = "Hiring Hall",
    order = 2,
    x = 350,
    y = 120,
    w = 270,
    h = 130,
    panel = "hiring",
    unlockPrestige = 1,
}
