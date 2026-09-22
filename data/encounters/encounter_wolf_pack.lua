-- THE WOLF PACK: the cheapest honest combo in the game, and it needed no new bodies at all.
--
-- The alpha and the grunts have both existed since the first week of this project and have never stood
-- on a board together -- encounter_wolf.lua fields grunts and nothing else. Put the alpha in and the
-- fight acquires a kill order: the pack is worth more with it alive, so the correct play is to reach
-- past the teeth in front of you.
--
-- Which is a lesson the human companies used to teach four ways over; they are deleted, so the animals
-- teach it now, on every floor.
return {
    name = "Wolf Pack",
    kind = "combat",
    weight = 5,
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
        local list = { "character_wolf_alpha" }
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 4) do
            list[#list + 1] = "character_wolf_grunt"
        end
        return list
    end,
}
