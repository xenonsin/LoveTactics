-- THE TAPESTRY: Arachne's (data/items/utility/utility_the_tapestry.lua; "Envy's Bestiary", 2026-10-03, slice C).
-- The weaver who out-wove a goddess. Every ability the company casts in her sight is woven, one thread on her
-- tapestry (status_woven); at 3 threads of one ability she casts it back at whoever cast it, once
-- (models/envy_seat.lua, EnvySeat.weave). Vary your casts.
return {
    name = "The Tapestry",
    description = "Weaves each ability a foe in sight casts. At 3 threads of one, casts it back at the caster once.",
    onAnyCast = function(ctx)
        require("models.envy_seat").weave(ctx.combat, ctx.unit, ctx.caster, ctx.castItem)
    end,
}
