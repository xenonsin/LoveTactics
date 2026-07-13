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
    duration = 4,
    disposition = "friendly", -- a hurt unit of the caster's side will step onto it
    onEnter = function(ctx)
        if not ctx.isAlly(ctx.unit) then return end
        -- Tag the Regeneration with its source so it ends the moment the unit steps off the hallowed
        -- ground (Combat.updateAuras), rather than lingering its full duration off the zone.
        ctx.applyStatus(ctx.unit, "regen", { source = "hazard_heal" })
    end,
}
