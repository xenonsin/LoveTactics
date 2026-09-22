-- Biome blueprint. The spire is Pride's ground, and it exists because Lust took the castle.
--
-- WHY PRIDE MOVED AT ALL. The castle was hers -- "a library that outlived every scholar who could read
-- it" -- and it is a good reading of her. But Lust's house is the Cathedral and its whole cast is
-- choristers, a suppliant and a bride: bodies that read in a hall and never did in a wood, which is
-- where the circle order had put them. One of the two had to move and Lust had the better claim to the
-- stone, so Pride took the ground that reads her gate instead.
--
-- THE GATE IS THE GROUND. Pride bars her stair on `worth` -- "she will not fight beneath herself"
-- (Descent.GATES) -- and a tower is that sentence as terrain. It is the one circle whose condition is
-- about ALTITUDE rather than about what you are carrying or what you have killed, and it is the only
-- one of the seven whose ground can state its own gate without a line of dialogue.
--
-- A WARREN LIKE THE CASTLE, AND NOT FOR THE SAME REASON. `rooms` is kept because Pride's cast fights in
-- ranks -- the Rank, the Colours, gilded pages behind a standard bearer -- and a doorway is where a
-- rank comes apart, which is what makes her circle's fights a matter of where you pull them through.
-- What changes is the story the carve tells: the castle's warren is a keep you are inside, this one is
-- a stair you are climbing, and the tileset is what has to carry that difference (data/tilesets/spire.lua).
--
-- Signature ground: EXPOSURE, and it is the one thing the castle cannot have. Up here there is nothing
-- overhead and nothing to put your back to, so the ground opens whoever stands in it to the point
-- (data/hazards/hazard_exposure.lua). A keep's threshold punishes the body holding a doorway; a tower's
-- open span punishes the body that stopped moving on it -- the same idea about formations, told from the
-- other side, which is what keeps the two strata from playing the same.
return {
    -- A PLACE, not a terrain category (models/biome.lua's naming note). Compound + landform, no article,
    -- like every other ground the company travels to -- the two that keep "The" are buildings in or
    -- under the city, and this is neither.
    name = "Gallowglass Spire",
    tileset = "spire", -- data/tilesets/spire.lua (art for this biome)
    layout = "rooms", -- chambers and landings, cut by recursive splits (as the castle carves)
    spacing = 2, -- a warren, like the keep it was cut out of
    rivers = 0,  -- no rivers up a tower
    hazard = { id = "hazard_exposure", min = 1, max = 3 },
}
