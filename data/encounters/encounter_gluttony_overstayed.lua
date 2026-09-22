-- THE OVERSTAYED: a Lodge company that stopped going home, met on the fen it stopped leaving.
--
-- The circle's own sin worn by people rather than by animals. A Lodge company is paid by the floor
-- and provisioned for a week, and this one has been down long enough to have eaten everything it
-- brought and then everything else -- so it fights the way a hunting party fights, from range and
-- from cover, and it does not withdraw, because withdrawing is the thing it has forgotten how to do.
--
-- Bodied chaff, so it CARRIES (docs/bestiary.md): every one of these has Lodge stock in its grid and
-- can hold an authored drop list (docs/drops.md). That is the whole reason this stop exists --
-- Gluttony's floor had five bodies on it and none of them had hands.
--
-- Weight and scaling follow the circle's existing traffic (encounter_gluttony_*): a common stop, a lead
-- plus beaters, and one more beater per stretch of the calendar so a deep floor reads as more of the
-- same rather than as something else.
return {
    name = "The Overstayed",
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
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_druid" }
        for _ = 1, 2 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_archer"
            list[#list + 1] = "character_herbalist"
        end
        -- ...and a third rank once the floors are deep enough to want one.
        if (ctx.depth or 1) >= 12 then list[#list + 1] = "character_shaman" end
        return list
    end,
}
