-- Building blueprint. THE INN: the only place in the game that sets a bone.
--
-- WHAT IT IS FOR. A body that goes down in a fight comes out of it WOUNDED (models/wound.lua) -- a share
-- of its health pool reserved and unreachable, and debuffs stacking as they accumulate -- and nothing
-- underground can undo that. The rest stop on a floor gives back half of what is left; only a night here
-- gives back the body. A company that keeps descending without stopping keeps getting worse, and this is
-- the door that costs money to make it stop being true.
--
-- Priced per head (models/gate.lua's Gate.INN_PER_HEAD), so a full company is dearer than a lone
-- survivor -- which is the right way round, since a full company is exactly when a night is worth most.
--
-- IT WAS A ROW ON THE GATE SCREEN. The town is the town -- the tavern where you find people, the inn
-- where you sleep, the houses where you buy -- and the gate is a stair with a lamp over it whose only
-- job is to go down. Wizardry's own split: the castle holds the counters, the dungeon entrance sits at
-- the edge of town where there is nothing to do but enter.
return {
    name = "The Inn",
    order = 3,
    x = 490,
    y = 120,
    w = 300,
    h = 130,
    panel = "inn",
    unlockPrestige = 1,
}
