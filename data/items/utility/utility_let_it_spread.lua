-- LET IT SPREAD: a charm whose entire function is to make its owner MORE cursed, on a clock they do not
-- control (models/curse.lua's Curse.spreadWithin, docs/curses.md).
--
-- PASSIVE RATHER THAN A CAST, and that changes the fantasy completely. An ability is a thing you do; a
-- passive is a thing you AGREED TO. Put this in a cell and the company gets more cursed after fights it
-- had no say in, because the counting shelf pays by the hex and you decided that was a trade worth
-- making. Nobody makes you take it out.
--
-- IT NEEDS NO NEW ENGINE AT ALL: `encounterCleared` is already in ItemHook.EVENTS and is already
-- dispatched per bearer between fights, which is the same seam The Spreading (the depth-14 curse) fires
-- on. The two are the same mechanic met from opposite ends -- one happens TO a player at the bottom of
-- the rift, and this one is bought at the top by a player who wants it.
--
-- ONLY THE BEARER'S OWN GRID, and only into a cell that can take a hex. So it runs out: a body whose
-- nine cells are all hexed simply stops spreading, and the ceiling is reached rather than enforced.
return {
    name = "Let It Spread",
    description = "After each fight, one of the bearer's hexes may creep into a neighbouring cell.",
    flavor = "He stopped pulling them out somewhere around the third floor. It goes faster now.",
    sprite = "assets/items/let_it_spread.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "shaman",
    unlockQuests = 7,
    dropTier = 7,
    encounterCleared = function(_, ctx)
        -- A third of the time, and only off a hex the bearer already has: this charm does not CREATE a
        -- curse, it moves one that is already there into a second cell. A clean body carrying it is
        -- carrying a dead charm, which is the honest cost of the build it belongs to.
        local Curse = require("models.curse")
        local hexed = Curse.hexedOn(ctx.char)
        if #hexed == 0 then return end
        local roll = (love and love.math and love.math.random) or math.random
        if roll(3) ~= 1 then return end
        if Curse.spreadWithin(ctx.char, hexed[1]) and ctx.say then
            ctx.say("The binding finds another piece")
        end
    end,
}
