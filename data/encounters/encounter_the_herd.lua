-- THE HERD: what a stag looks like when it is not alone.
--
-- encounter_stag.lua is the single worst offender in the pre-existing pool -- one body against a
-- company of four, rating 582% against Muster.WALK_OVER of 200, which is to say every marker it drew
-- went calm and the fight offered to resolve itself instead of opening a board. It stays, because a
-- lone beast IS correct texture and walking one off is the option working rather than failing.
--
-- This is the version that is a fight. Same body, brought in the numbers it lives in.
return {
    name = "The Herd",
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
    -- LOCKED TO THE WOOD, which is the circle-lock rule arriving rather than a retune: humans
    -- float to every floor and everything else belongs to exactly one circle. This was shared
    -- road stock on all fifteen, and the beast band is Gluttony's identity now.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = {}
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 6) do
            list[#list + 1] = "character_stag_beast"
        end
        return list
    end,
}
