-- Sanctuary: hallowed ground. An ALLY entering it gains Regeneration (data/status/regen.lua), mending
-- health at the start of each of its turns; a foe of the caster stands on it untouched. The blessing
-- lingers for a duration. Because only the owning side profits, the enemy AI is drawn to a sanctuary
-- of its own (disposition "friendly", weighed side-aware in Hazard.tileBias) and ignores the party's.
-- Summoned by the priest's Sanctuary spell (data/items/ability/ability_sanctuary.lua).
return {
    name = "Sanctuary",
    description = "Hallowed ground: grants Regeneration to allies who stand within.",
    sprite = "assets/hazards/sanctuary.png",
    tags = { "holy" },
    duration = 15, -- ticks the hallowed ground lingers: ~3 turns at Status.TICKS_PER_TURN
    disposition = "friendly", -- a hurt unit of the caster's side will step onto it
    onEnter = function(ctx)
        if not ctx.isAlly(ctx.unit) then return end
        -- Regeneration does not declare `lingers`, so it is zone-bound: this grant is stamped with the
        -- Sanctuary as its source automatically, and ends the moment the unit steps off the hallowed
        -- ground or the ground itself fades. ctx.amount (the Sanctuary item's level-scaled heal) sets
        -- how much it mends; nil falls back to regen's own.
        ctx.applyStatus(ctx.unit, "status_regen", { magnitude = ctx.amount })
    end,
}
