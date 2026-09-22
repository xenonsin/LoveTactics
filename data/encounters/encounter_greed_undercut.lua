-- THE UNDERCUT: another company on the same seam, which is a worse problem than the seam.
--
-- Greed's ordinary traffic is vermin that take coin and run (encounter_greed_the_chitters). This is
-- the version with a plan: people who came down for exactly what you came down for and have decided
-- the cheapest way to get it is off your bodies. They open on the flank and they do not spread out,
-- because a duelist's whole bonus is refusing to let go of one target.
--
-- The blueprints were authored and then never placed anywhere -- character_rogue and
-- character_duelist have sat unreachable since the Quest Board was retired.
--
-- Weight and scaling follow the circle's existing traffic (encounter_greed_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Undercut",
    kind = "combat",
    weight = 4,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "swamp" end,
    composition = function(ctx)
        local list = { "character_duelist" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_rogue"
        end
        return list
    end,
}
