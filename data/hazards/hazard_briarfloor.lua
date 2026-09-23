-- Briarfloor: thorn ground the Dryad grows, and it bills a body for every tile it crosses -- whether it
-- walked across or was thrown across.
--
-- NO NEW ENGINE, AND THAT IS WHY IT WORKS. Every tile a body enters routes through Combat.enterTile,
-- and every forced step does too (shoveStep: a knockback, a pull, a trampling charge). So a hazard that
-- bites on entry already bites once per tile of a slide: a harpy's gust that throws a body two tiles
-- across a briar patch has billed it twice, and the Nymph's Mistlight has made it three. The Dryad line
-- lives in the Move half of the Lust circle, and this is its whole argument for being there -- the flock
-- throws you, and the floor charges by the yard.
--
-- SIDED TO WHOEVER GREW IT, so her own line and the flock beside her walk it freely. A company that
-- carries the spell out of the Rood Loft grows ground its own shoves are billed on, which pays off every
-- mace and shield-shove it already owns.
return {
    name = "Briarfloor",
    description = "Foes take damage for every tile of it they cross, walked or thrown.",
    tags = { "nature", "burnable" },
    duration = 36,           -- about six turns: the patch is a feature of the room, not of the cast
    disposition = "hostile", -- the enemy AI paths around a foe's thorns
    dousedByTags = { "fire" }, -- a fire cast clears it -- the same answer the tree is open to
    onEnter = function(ctx)
        if ctx.isAlly(ctx.unit) then return end
        ctx.damage(ctx.unit, ctx.amount or 4, { "physical", "pierce" })
    end,
}
