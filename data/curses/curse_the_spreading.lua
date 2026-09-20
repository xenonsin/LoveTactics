-- THE SPREADING: the only hex with a clock on it.
--
-- After every fight the bearer clears it may creep into the next cell over and take whatever is sitting
-- there (Curse.spreadWithin, fired through the `encounterCleared` hook models/item_hook.lua already
-- dispatches for items and now dispatches for curses).
--
-- IT MAKES THE CATHEDRAL A DECISION ABOUT TIMING rather than a chore, which nothing else here does.
-- Every other curse is a fixed cost you pay whenever you get round to it; this one is a cost that GROWS
-- while you put it off, so "one more floor or go home" stops being a question about health bars and
-- becomes a question about the rite. The deepest hex in the rift ought to be the one that gets worse.
--
-- EACH SPREAD IS SEPARATELY LIFTABLE, so it is pressure and never a wipe. A company that lets it run for
-- three floors walks into the Cathedral with four rows on the altar and a real bill -- which is a story
-- about a decision they made, not a punishment the game handed out.
--
-- ONE STEP PER FIGHT AND ONLY INTO A CELL THAT CAN TAKE ONE. Curse.spreadWithin refuses a neighbour that
-- is already hexed, a consumable stack, a natural weapon and a warded kit, so a grid full of hexes
-- simply stops spreading -- the ceiling is the nine cells, and it is reached rather than enforced.
return {
    name = "The Spreading",
    description = "After each fight, the hex may creep into a neighbouring grid cell.",
    binds = true,
    depth = 14,
    fee = 450,
    encounterCleared = function(item, ctx)
        -- A quarter of the time, and only on the body actually carrying it. `ctx.char` is the bearer
        -- (models/item_hook.lua sets it per item), so a company with two Spreadings rolls twice --
        -- which is the stacking story told in grid cells rather than in a ladder.
        local Curse = require("models.curse")
        local roll = (love and love.math and love.math.random) or math.random
        if roll(4) ~= 1 then return end
        local spread = Curse.spreadWithin(ctx.char, item)
        if spread and ctx.say then
            ctx.say("The Spreading takes hold of another piece")
        end
    end,
}
