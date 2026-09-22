-- ROAD BANDITS: the cheapest company in the rift, and the one a first floor should meet.
--
-- Three bandits and the rogue who talked them into it. Every body in it is a ROOT class (rung 0), which
-- is what makes it legal on the opening floor -- the disciplines all ask for rung 3 or more, so a
-- shallow company that draws from them has nothing but anchors in it.
--
-- IT FLOATS, WHICH IS THE WHOLE OF WHY IT IS HUMAN. Under the circle-lock rule every body that is not
-- human belongs to exactly one circle and appears nowhere else -- so the human band is the only thing
-- that can stand on any floor, and it is therefore what keeps a floor from being empty at a depth its
-- circle has not been authored out to yet. Nothing here declares a `condition`: that absence is the
-- feature.
--
-- ITS DEPTH IS ITS `depth` AND THAT IS A STOPGAP. What ought to place this is a depth band read off
-- the floor count, the way an item's `unlockLevel` is -- the gate is still the campaign calendar's day
-- and the descent borrows one. Until that lands, the rung of the bodies below is the real statement
-- about where this belongs: a company is made of what the floor could plausibly have produced
-- (Class.gateLevel, which models/warband.lua's generator already reads).
return {
    name = "Road Bandits",
    kind = "combat",
    weight = 6,
    depth = 1,
    -- One more of them the deeper you are, which is the only thing about this fight that changes.
    composition = function(ctx)
        local list = { "character_rogue" }
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_bandit"
        end
        return list
    end,
}
