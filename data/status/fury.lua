-- Fury: a berserk window, and the first user of the "record state while active, resolve on expiry"
-- system (models/status.lua onDealDamage / onExpire). While it stands the bearer CANNOT die --
-- `preventsDeath` floors it at 1 HP through any blow (Combat.dealFlatDamage) -- and every point of
-- damage it deals is banked on `status.recorded` (onDealDamage, fired from Combat.dealDamage). When
-- the window closes, and only then, it heals for half of everything it banked (onExpire): rage spent,
-- wounds paid back. The Fury ability itself drops the caster to 1 HP on cast (data/items/ability).
return {
    name = "Fury",
    abbr = "Fry",
    description = "Cannot die; at the end, heals for half the damage dealt while raging.",
    color = { 0.85, 0.20, 0.20 }, -- badge tint (blood red)
    duration = 12,
    preventsDeath = true,
    onApply = function(ctx)
        ctx.status.recorded = ctx.status.recorded or 0 -- running tally of damage dealt while raging
        -- Lighting the fuse spends the bearer down to the wick. Done HERE (not in the ability's
        -- effect) so it runs only on a real application -- the inventory/aim previews stub applyStatus,
        -- so hovering Fury never touches the unit's actual HP.
        ctx.unit.char.stats.health.current = 1
    end,
    onDealDamage = function(ctx)
        ctx.status.recorded = (ctx.status.recorded or 0) + (ctx.amount or 0)
    end,
    onExpire = function(ctx)
        local payback = math.floor((ctx.status.recorded or 0) * 0.5)
        if payback > 0 then ctx.heal(ctx.unit, payback) end
    end,
}
