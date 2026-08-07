-- Regeneration: a restorative buff and the friendly mirror of Burn (data/status/burn.lua). It heals on
-- the CLOCK -- every elapsed tick recovers flat health (ctx.heal routes through Combat.applyHeal,
-- clamped to max) -- with `magnitude` quoted per turn and ctx.accrue spreading it over the ticks a turn
-- is worth. Granted by standing in a Sanctuary hazard (data/hazards/hazard_heal.lua) or in the shadow
-- of a Renewal Banner (data/items/ability/ability_renewal_banner.lua).
--
-- Where Burn `lingers`, this does NOT: it is the archetype of a ZONE-BOUND status. Hallowed ground
-- heals you while you stand on it and not one tick after you step off, and the moment the zone itself
-- dies -- its duration spent, or the banner that cast it cut down -- the healing stops with it. That
-- rule lives in models/hazard.lua and needs nothing here but the absence of `lingers`.
--
-- Its `duration` is therefore only a backstop for a Regeneration handed out by something that is NOT a
-- zone (a potion, a spell), which has no ground to stand on and so just runs its course. Inside a zone
-- the duration never gets a chance to matter: it is refreshed every tick the unit remains.
return {
    name = "Regeneration",
    abbr = "Rgn",
    description = "Blessed: recovers health as time passes.",
    color = { 0.420, 0.787, 0.502 }, -- badge tint (restorative green)
    -- Marks this as a HEALING condition, so a body wearing it (or a zone granting it) draws the blue
    -- heal-crosses rather than a buff's chevrons -- read by ui/field_fx.lua's category resolver and by
    -- Hazard.preview, which is how a Sanctuary is known to be a heal without the hazard saying so.
    restorative = true,
    -- Only ever drawn where NO hallowed ground is already drawing it -- a potion's regeneration, not a
    -- Sanctuary's. The zone-bound grant is redundant with the zone by construction (ui/field_fx.lua).
    fx = { field = true },
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN (only ever reached off a zone -- see above)
    magnitude = 8, -- health restored per turn's worth of ticks
    onTick = function(ctx)
        local n = ctx.accrue(ctx.magnitude)
        if n > 0 then ctx.heal(ctx.unit, n) end
    end,
}
