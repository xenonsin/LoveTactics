-- Thicketing: the hunter calls a ring of thorn and green wood up around one body. Eight tiles of it,
-- and the thing in the middle has to cut its way out.
--
-- A CAGE RATHER THAN A WALL, and the hunter's version of it differs from the knight's Closed Ring in
-- the one way that matters: this is cheap, fast, and short-lived. The knight's ring is a prison that
-- takes a piece out of the battle for three turns; this is a DELAY that costs a foe its move and buys
-- the hunter the range it needs. Trapper's work -- setup and then payoff (docs/classes.md) -- rather
-- than the wall's.
--
-- Which is why it belongs on the gluttony shelf and why it is gated the way it is: it wants a `bow`
-- beside it in the grid, and that is not decoration. Thicketing a foe who is already at range does
-- nothing at all. The whole play is thicket-then-shoot: cage the thing that was closing on you, walk
-- backwards, and spend the two turns it takes to chop free putting arrows into it. An archer without
-- a bow beside this has bought a spell that saves them once and never wins anything.
--
-- IT WORKS ON EMPTY GROUND TOO, which is the second use and the one that reads as trapping rather than
-- as panic: thicket a doorway, a bridge, or the tile a reinforcement wave is about to walk onto. The
-- centre is left open exactly as the Closed Ring's is, so the same eight segments serve both readings.
--
-- The thorns are the same conjured barrier every other wall in this game raises -- tagged `illusion`,
-- so a Dispel clears the whole cage at once. A hunter who cages an enemy mage should expect the mage
-- to simply undo it, and should have shot it instead.
return {
    name = "Thicketing",
    description = "Grows a ring of thorn around one tile: whatever is inside must cut its way out.",
    flavor = "The Lodge does not build fences. It asks the wood to be somewhere, and the wood obliges.",
    sprite = "assets/items/ability_thicketing.png",
    type = "ability",
    tags = { "earth" },
    class = "hunter",
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        requiresSight = true,
        speed = 3, -- fast: it is a reaction to something closing, and a slow one arrives too late
        cost = { stat = "stamina", amount = 10 },
        support = true,
        requiresAdjacent = { tag = "bow" },
        effect = function(fx)
            -- The eight cells around the aimed one; the centre is where the body is, and Wall.place
            -- would refuse it anyway. Thinner and shorter-lived than the knight's ring on both axes --
            -- this is meant to be cut through, and cut through soon.
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        fx.placeWall(fx.tx + dx, fx.ty + dy, "illusory_wall",
                            { health = 12 + fx.level, duration = 10 + fx.level })
                    end
                end
            end
        end,
    },
}
