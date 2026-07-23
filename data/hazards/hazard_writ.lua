-- A Writ of Fire: a mark burned into the ground that comes due. It does nothing at all while it lies
-- there -- no damage on entry, no status, no cost to cross -- and then its duration runs out and it
-- takes everything standing on it very hard indeed.
--
-- THE FIRST DELAYED STRIKE IN THE GAME, and it is built entirely out of a rule the hazard model
-- already had: `onExpire` fires when the ground's clock reaches zero. Nothing new was needed. What is
-- new is using it as the WHOLE effect rather than as a tidy-up.
--
-- That inverts what a hazard normally is. Every other zone in this catalog punishes standing in it, so
-- the counterplay is to leave and the cost of casting it is that a sensible enemy simply walks around.
-- A writ punishes standing in it LATER, so the counterplay is to read the board and be elsewhere on a
-- specific beat -- and the enemy AI's hazard avoidance, which steers around hostile ground, is exactly
-- the behaviour that walks them off it in time. Against a player it is a threat you place and then
-- spend the rest of the fight herding people onto: a root, a shove, a wall, a duel.
--
-- Unsided. It burns whoever is standing there when the hour comes, and the caster's own line is not
-- exempt -- which is the only thing that keeps a fire-and-forget nuke honest.
return {
    name = "Writ of Fire",
    description = "A burning mark: takes everything standing on it when it finally comes due.",
    sprite = "assets/hazards/writ.png",
    tags = { "fire" },
    duration = 6,             -- ~1 turn's grace: long enough to run, short enough to be a threat
    disposition = "hostile",  -- the enemy AI reads it as ground to be off
    dousedByTags = { "water" }, -- a rain cloud or a water ball washes the mark out before it burns
    onExpire = function(ctx)
        -- Radius 0: exactly the tile the mark was burned into. A writ is a POINT, and its whole cost
        -- is that it has to be aimed a turn early -- widening it here would pay that cost back.
        local amount = ctx.hazard.amount or 24
        for _, u in ipairs(ctx.unitsNear(ctx.hazard.x, ctx.hazard.y, 0)) do
            ctx.damage(u, amount, { "fire", "magical" })
        end
    end,
}
