-- Sanctuary: hallowed ground. A unit entering it gains Regeneration (data/status/regen.lua), mending
-- health at the start of each of its turns. The blessing lingers for a duration. Friendly to the AI:
-- a wounded enemy will detour onto it to heal (it mends whoever stands in it, regardless of who cast
-- it). Summoned by the priest's Sanctuary spell (data/items/ability/ability_sanctuary.lua).
return {
    name = "Sanctuary",
    description = "Hallowed ground: grants Regeneration to those who stand within.",
    sprite = "assets/hazards/sanctuary.png",
    tags = { "holy" },
    duration = 4,
    disposition = "friendly", -- a hurt enemy will step onto it
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "regen")
    end,
}
