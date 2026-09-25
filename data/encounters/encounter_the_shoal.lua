-- THE SHOAL: the Mere's ordinary traffic, and the fight that teaches the fen.
--
-- A screen of Shoalkin with a Fen Lancer working the bank behind them. It is a skirmish rather than a
-- set-piece, so it opens at the plain four-body ceiling -- which is the right size for the lesson: the
-- company learns that the walls of this arena are water, that the things in them do not pay to cross
-- it, and that a spear can reach the second rank from ground nobody can follow it onto.
--
-- Gated on the SWAMP because that is where the channels are (Arena.BIOME_TERRAIN's blocker), and on a
-- board with no water on it the Mere is simply a slow pack with a spear.
local Band = require("models.band")

return {
    name = "The Shoal",
    kind = "combat",
    weight = 3,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "swamp" end,
    -- LUST'S SEAT ONLY (2026-09-25). The Shoal came down with the swap and is placed the way the
    -- mushroom folk are, on Keno's note: ONE home fight on ONE floor (floor four, as the Ossuary is), and
    -- its chaff padding the circle's other fen fights (the Reed Choir, the Lorelei's Rock, the Still
    -- Water). Floor three already has the naga in the Reed Choir.
    rung = 2,
    -- THICKENS EARLY AND FLATTENS, which is the shape both measurements asked for. A shoal of two
    -- behind one lancer is a fight a levelled company walks over (tests/descent_spec.lua rates it on
    -- floor three); a shoal that kept growing is a fight that stops ending (tests/skirmish_spec.lua
    -- caps an ordinary road stop at 22 unit-turns). One more body early, none later.
    --
    -- SO IT DECLINES THE ROLL (`vary = 0`), and it is the stop that proves the escape hatch is needed.
    -- Every other ordinary stop fields a band (models/band.lua); this one is pinned between two
    -- measurements that face each other, with exactly one number between them. Banded at +/-1 it rolled
    -- a shoal of two at depth eleven and the fight ran 33 unit-turns against the budget of 22 -- which
    -- is the finding both this header and tests/support/slow_road_fights.lua already record from the
    -- other side: where neither party can close, a LIGHTER fight is a longer one.
    --
    -- RETUNED 2026-09-23, WHEN IT WAS FIRST MEASURED ON ITS OWN GROUND. tests/skirmish_spec.lua stood every
    -- ordinary fight on a forest board, and there this one "won" in 14 unit-turns only because a Shoalkin
    -- walked into sweetbriar and was charmed to the party's side -- a planner that priced the stop tile
    -- and not the road. Met on the swamp, by a planner that walks round hostile ground, a depth-11 company
    -- LOST it at 35-41 on three seeds in five. Two changes, measured across five seeds on the swamp:
    --   * the shoal caps at TWO (was three): three shoalkin at the depth ceiling is what lost it
    --   * the Shoalkin act at speed 3 (was 4): two alone still lost one seed in five
    -- Together: W18 W15 W24 W14 W14 -- all five won, the spec's own seed at 18. Health, defense and the
    -- damage stat were tried and moved nothing (the ladder's growth sets those at depth), which is why the
    -- levers are the count and the tempo.
    composition = function(ctx)
        local list = { "character_fen_lancer" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 2, per = 2, max = 2, vary = 0 })
    end,
}
