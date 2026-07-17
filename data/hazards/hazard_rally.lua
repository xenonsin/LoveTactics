-- Rally: the ground a planted Rally Banner holds. Allies standing in the banner's shadow are Inspired
-- (data/status/inspiration.lua) -- courage in the swing and the shield. Laid as a 3x3 of these tiles
-- around the standard by data/items/ability/ability_rally_banner.lua, every one of them OWNED by the
-- banner unit: cut the banner down and Hazard.dropOwnedBy takes the whole square with it, and the
-- Inspiration lifts a beat later when Hazard.reap finds no rallying ground under anyone.
--
-- The zone is what the banner IS, mechanically. The banner itself takes no turns and does nothing (see
-- data/characters/banner.lua) -- it is a body with health whose only job is to hold this ground open.
--
-- Each kind of banner needs its OWN zone id, rather than one shared "banner" zone carrying the status
-- as a payload, because a zone-bound status remembers the id that granted it and asks "is a zone of
-- THAT id still under me?". Share the id and a Sacred Banner's square would happily keep a dead Rally
-- Banner's Inspiration alive. Compare data/hazards/hazard_sacred.lua and hazard_renewal.lua, which are
-- this file with one word changed.
return {
    name = "Rally",
    description = "A banner's shadow: allies standing within are Inspired.",
    sprite = "assets/hazards/rally.png",
    tags = { "morale" },
    -- Effectively forever: this ground answers to the banner's life, not to a clock. The banner dies
    -- long before the count runs out, and Hazard.dropOwnedBy is what really ends it.
    duration = 9999,
    disposition = "friendly", -- an ally of the banner's side will step into it; the enemy gains nothing
    onEnter = function(ctx)
        -- A standard does not rally itself. The banner stands on the middle tile of its own square, so
        -- without this it would wear the Inspiration it exists to hand out.
        if ctx.unit == ctx.hazard.owner then return end
        if not ctx.isAlly(ctx.unit) then return end
        -- Inspiration declares no `lingers`, so this grant is stamped with "hazard_rally" as its source
        -- automatically and lasts exactly as long as the unit stands here.
        ctx.applyStatus(ctx.unit, "inspiration", { magnitude = ctx.amount })
    end,
}
