-- THE EMPLACEMENT: a fight about denial rather than damage.
--
-- It builds a position and dares you to walk into it. The artificer emplaces sentries, the saboteur's
-- charges price the ground between you and them, and the sentinel's Shared Burden keeps the artificer
-- alive long enough to do it twice. Nothing here chases you; everything here makes the tile you wanted
-- to stand on cost something.
--
-- Which is what a warren carve is FOR, and why this one earns its weight on the deep floors: a corridor
-- fight against a company that has already decided where the corridor ends.
return {
    name = "The Emplacement",
    kind = "elite",
    weight = 2,
    minDay = 9,
    composition = function(ctx)
        local list = {
            "character_artificer",      -- setup: the sentries, which claim the ground
            "character_ordnance_sentry", -- payoff: what the claimed ground is worth
            "character_sentinel",       -- multiplier: keeps the artificer standing
            "character_saboteur",       -- the charges, on the route you were going to take
            "character_ordnance_sentry",
        }
        for _ = 1, math.floor((ctx.day or 1) / 18) do list[#list + 1] = "character_ordnance_sentry" end
        return list
    end,
}
