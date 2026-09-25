-- THE FEN OOZE: the swamp's other ordinary traffic, and the stop where the party finds out its
-- swords are decoration.
--
-- Paired against data/encounters/encounter_gluttony_fen_swarm.lua deliberately, because the two are
-- opposite lessons at the same rung. The swarm is an arithmetic problem -- lots of cheap bodies, and
-- every order of operations feeds the hound a little. This is a LOADOUT problem: one kind of body,
-- three of it, and nothing the melee line is carrying touches any of them
-- (data/characters/character_slime.lua). A company that walks into the fen with four blades and no
-- element learns the rule here, cheaply, well above the crowned version of it.
--
-- NO ESCORT, and that is the point. A slime beside a hound would let the party spend the fight on the
-- hound and call it a win; a board with nothing on it but slimes has exactly one question on it.
--
-- IT SHIPPED AS `combat` AND THE MEASUREMENT SAID NO. tests/skirmish_spec.lua autobattles every
-- ordinary stop with a real company at floor 11 and holds it to 22 unit-turns; this one took 56. That is
-- not a tuning miss, it is the body working as designed -- three things a melee line cannot hurt is a
-- long fight by construction, and no count or health figure fixes that without deleting the puzzle.
--
-- tests/support/slow_road_fights.lua poses the choice outright -- "whether the honest fix is to
-- shorten these fights or to stop calling them ordinary is a design question this file deliberately
-- does not answer" -- and for this body the answer is the second one. It is `elite`, which is the
-- right shelf for it in every way that matters: an elite is a MARKED stop the player can read off the
-- board, price against the company, and route around (the Etrian-FOE job the descent kept when it
-- took ordinary combat off the map). A body whose whole content is "did you bring an element" should
-- be a thing you SEE and decide about, never a thing that jumps you in a corridor.
--
-- Adding a row to the slow-fight backlog was the other way out and it is not available: that file is a
-- ratchet for debt already shipped, its header says not to raise a number to make a build pass, and
-- filing brand-new content as pre-existing debt is the same move wearing a different hat.
--
-- Locked to Greed's keep by `ctx.biome` (it came up out of the fen with Greed in the 2026-09-25 swap), the same predicate every circle keeps its stock with, so the
-- stratum means something and no engine work was needed to say so.
--
-- THE DEPTH IS THE SAFETY MARGIN, and it is worth naming because this is the only body in the game a
-- company can be unable to hurt AT ALL. Everything else answers a bad loadout with a long fight; this
-- answers it with no fight. The outs are real -- a rolled fight arrives on the deploy screen with a
-- Run Away plate over it, and a wipe underground costs the haul rather than the save (docs/the-count.md)
-- -- but a Run Away roll can fail, so the body must not be met before a company has plausibly acquired
-- an element. `depth` is the whole of that guarantee: on a descent the day is depth (Descent.poolDay),
-- so 6 is several floors and several homecomings of shelves and drops rather than the mouth of the rift.
local Band = require("models.band")

return {
    name = "The Fen Ooze",
    kind = "elite",
    -- Low, and under the King's own 2 is not available -- 2 is already the floor the circle's elites
    -- sit at. Level with it, so the fen deals the lesson about as often as the thing that charges for
    -- it, and the ELITE_SHARE cap keeps either from crowding the board.
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- WHICH of the two is `rung` below, and on an elite it is REQUIRED rather than optional: one elite,
    -- one floor. A biome lock places a body in the stratum and then leaves it standing on both of that
    -- stratum's stairs, which makes a landmark into traffic -- see models/encounter.lua's eligibility
    -- note for the whole argument, and tests/elite_floor_spec.lua for the count that holds it.
    --
    -- Descent.SINS' `elites` is the SEPARATE question of which of a floor's candidates the floor is
    -- ABOUT (billed at ELITE_NAMED_WEIGHT). The rung says where a thing may stand at all.
    condition = function(ctx) return ctx.biome == "cave" end,
    -- RUNG 1 -- the approach, and Greed bills it there. Its own header argues this lesson must land
    -- "well above the crowned version of it" -- and above, in a rift, is the approach floor.
    rung = 1,
    composition = function(ctx)
        -- Two at the mouth of the fen, three deeper in. It climbs slowly and stops well inside
        -- Arena.ELITE_CAP (6): this is a puzzle about what you brought, and a fourth body only makes
        -- the same answer take longer -- which is why `max` is a hard 3 the band may not roll past.
        return Band.fill({}, ctx, "character_slime", { base = 2, per = 4, max = 3 })
    end,
}
