-- VITAE: a Blood-Ghoul's draught drunk (data/items/consumable/consumable_vitae.lua). +3 Damage for three turns --
-- and when it runs out, the drinker carries the Thirst for three more (status_borrowed_thirst).
return {
    name = "Vitae",
    abbr = "Vit",
    description = "Vitae: increase damage by 3. When it ends, you carry the Thirst.",
    color = { 0.700, 0.100, 0.160 }, -- badge tint (vitae)
    duration = 15, -- three turns at Status.TICKS_PER_TURN
    statBonus = { damage = 3 },
    onExpire = function(ctx)
        if ctx.unit and ctx.unit.alive then ctx.applyStatus(ctx.unit, "status_borrowed_thirst") end
    end,
}
