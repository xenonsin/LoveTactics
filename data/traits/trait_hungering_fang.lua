-- THE HUNGERING FANG: the Fledgling's drop (data/items/weapon/weapon_hungering_fang.lua). +3 Damage for each turn
-- the bearer ends without drawing blood (status_hungering, three at most), and the next hit spends all of it.
return {
    name = "Hungering Fang",
    description = "Increase damage by 3 for each turn you end without drawing blood, up to 3 times. The next hit consumes it.",
    notAReaction = true,
    onCast = function(ctx)
        local u = ctx.unit
        if not (u and (ctx.damageDealt or 0) > 0) then return end
        u._fangFed = true
        if require("models.status").has(u, "status_hungering") then ctx.clearStatus(u, "status_hungering") end
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if u._fangFed then u._fangFed = nil return end
        ctx.applyStatus(u, "status_hungering")
    end,
}
