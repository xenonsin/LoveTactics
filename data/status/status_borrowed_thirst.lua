-- THE BORROWED THIRST: what Vitae leaves behind (status_vitae). Draw blood from a living body before it runs out
-- and it is paid (models/thirst.lua marks it `slaked` and lifts it). Let it run out dry and the drinker spends one
-- turn in Bloodlust.
return {
    name = "Borrowed Thirst",
    abbr = "Thr",
    description = "Borrowed Thirst: draw blood from a living body before it ends, or be in Bloodlust for a turn.",
    color = { 0.560, 0.080, 0.140 }, -- badge tint (dark blood)
    duration = 15, -- three turns
    onExpire = function(ctx)
        local u = ctx.unit
        if ctx.status.slaked or not (u and u.alive) then return end
        require("models.thirst").enterBloodlust(ctx.combat, u, 5) -- one turn
    end,
}
