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
    minDay = 2,
    condition = function(ctx) return ctx.biome == "underworld" end,
    composition = function(ctx)
        local list = { "character_duelist" }
        for _ = 1, 2 + math.floor((ctx.day or 1) / 14) do
            list[#list + 1] = "character_rogue"
        end
        return list
    end,
}
