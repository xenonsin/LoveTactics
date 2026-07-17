-- Renewing ground: the square a planted Renewal Banner holds. Allies standing in it gain Regeneration
-- (data/status/regen.lua), mending as the clock runs. Laid as a 3x3 around the standard by
-- data/items/ability/ability_renewal_banner.lua, owned by the banner unit -- see
-- data/hazards/hazard_rally.lua for why each banner needs a zone id of its own.
--
-- Grants the same Regeneration a Sanctuary does (data/hazards/hazard_heal.lua) and on the same terms:
-- the two are the same idea reached by different means -- a priest consecrating ground for a few ticks,
-- and a standard holding it for as long as the standard lives.
return {
    name = "Renewing Ground",
    description = "A renewal banner's shadow: allies standing within recover health.",
    sprite = "assets/hazards/renewal.png",
    tags = { "holy" },
    duration = 9999, -- answers to the banner's life, not a clock (Hazard.dropOwnedBy)
    disposition = "friendly",
    onEnter = function(ctx)
        if ctx.unit == ctx.hazard.owner then return end
        if not ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_regen", { magnitude = ctx.amount })
    end,
}
