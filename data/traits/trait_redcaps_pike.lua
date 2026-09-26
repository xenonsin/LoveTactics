-- THE REDCAP'S PIKE: a killing blow heals the bearer (data/items/weapon/weapon_redcaps_pike.lua). Any kill the
-- bearer makes (the fallen's lastAttacker), not only one made with the pike.
return {
    name = "Redcap's Pike",
    description = "A killing blow heals you for 20% of your max health.",
    notAReaction = true,
    share = 0.20,
    onAnyDeath = function(ctx)
        local u, fallen = ctx.unit, ctx.fallen
        if not (u and u.alive and fallen and fallen.lastAttacker == u and fallen.side ~= u.side) then return end
        local Combat = require("models.combat")
        ctx.heal(u, math.floor(Combat.unreservedMax(u.char, "health") * ctx.param("share", 0.2) + 0.5))
    end,
}
