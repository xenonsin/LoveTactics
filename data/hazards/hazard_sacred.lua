-- Sacred ground: the square a planted Sacred Banner holds. Allies standing in it are Blessed
-- (data/status/blessing.lua), striking harder with steel and spell alike. Laid as a 3x3 around the
-- standard by data/items/ability/ability_sacred_banner.lua, owned by the banner unit -- see
-- data/hazards/hazard_rally.lua, of which this is a copy with one status changed, for why each banner
-- needs a zone id of its own.
return {
    name = "Sacred Ground",
    description = "A sacred banner's shadow: allies standing within are Blessed.",
    sprite = "assets/hazards/sacred.png",
    tags = { "holy" },
    duration = 9999, -- answers to the banner's life, not a clock (Hazard.dropOwnedBy)
    disposition = "friendly",
    onEnter = function(ctx)
        if ctx.unit == ctx.hazard.owner then return end
        if not ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_blessing", { magnitude = ctx.amount })
    end,
}
