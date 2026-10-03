-- ONLY REPEATS: the Echo's (data/items/utility/utility_only_repeats.lua; "Envy's Bestiary", 2026-10-03, slice C).
-- The nymph who could only say what others said. A foe casts an ability within 3 of her, and she repeats its blow
-- at half power, from her own tile, at the caster (models/envy_seat.lua, EnvySeat.echo).
--
-- The player's Echo trait (data/traits/trait_echo.lua) lends a copy of an ALLY's cast at half power; this is that
-- rule turned on the company. A repeat is a blow, not a cast: it costs her nothing and ends no turn.
return {
    name = "Only Repeats",
    description = "When a foe within 3 casts an ability, repeat its blow at the caster at half power.",
    onAnyCast = function(ctx)
        require("models.envy_seat").echo(ctx.combat, ctx.unit, ctx.caster, ctx.castItem)
    end,
}
