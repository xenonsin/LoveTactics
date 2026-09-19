-- CURSE-BEARER: the tile one of the Unseeing's clan dies on takes the curse.
--
-- The sibling of data/traits/trait_cinderfall.lua, and deliberately a separate file rather than a
-- parameter on it -- a trait has no argument to read a hazard id out of when it is bound by a CALL
-- rather than granted by an item (there is no ctx.item here). Two five-line traits, each naming its own
-- fiction, beats one that has to be told what it is.
--
-- The real difference is not the hazard, it is WHERE THE RULE COMES FROM, and it matters. Cinderfall is
-- born on the body: a Wrath creature burns because of what it is. This is bound to the boar by
-- ability_the_call at the moment it is summoned (Summon.spawn's `opts.traits`, whose own header argues
-- exactly this case -- "traits the CALL binds to the creature, rather than ones the creature was born
-- with... they belong to the ability because that is what struck the bargain"). So the lord's clan
-- leaves curse where it falls and an ordinary roadside Wild Boar does not, with no second boar blueprint
-- to keep in step and no edit to data/characters/character_boar.lua.
--
-- onDeath (the bearer's own), not onAnyDeath: this is what the body leaves behind, not something it does
-- to others.
return {
    name = "Curse-Bearer",
    description = "Leaves curse on the tile it falls on.",
    onDeath = function(ctx)
        local u = ctx.unit
        if not (u and u.x and u.y) then return end
        ctx.placeHazard(u.x, u.y, "hazard_curse")
    end,
}
