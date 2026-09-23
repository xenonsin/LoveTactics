-- BRISTLE: the Manticore's hide, which throws quills at whoever is working it over. Borrowed from Dota's
-- Bristleback on review (2026-09-23): damage TAKEN banks toward a spray, and every `threshold` of it
-- looses one at every foe within `radius` -- a light pierce blow and a stack of status_quilled each.
--
-- It is what gives the quills a second source, and the one the PLAYER controls. The Tail Volley lays
-- them on a front line from range whatever the company does; this lays them on whoever chose to stand
-- next to the animal and hit it. A melee pile-on wears its quills; a kill from across the glade does
-- not. Its drop is the same rule at a shorter reach (utility_the_bristling), which is why the numbers
-- are read through ctx.param: the granting item may name its own.
--
-- THE TOTAL LIVES ON THE TRAIT INSTANCE (ctx.trait.banked), which is per body and per battle -- a unit's
-- traits are collected when it joins the field. What a spray is left over from carries to the next hit,
-- so three 7s spray exactly as one 21 does, which is the Bristleback rule and the one that makes a
-- hail of light blows no safer than one heavy one.
--
-- A SPRAY IS A REFLEX, NOT A SWING: flat damage with no hit roll (ctx.damage), as every thorn in the game
-- is. Its tags carry no `melee`, so a Quillhide it lands on does not answer it, and two bristling bodies
-- trading sprays stop at Trait.MAX_DEPTH long before either banks another 15.
return {
    name = "Bristle",
    description = "Every 15 damage taken, sprays quills at every foe within 2, inflicting Quilled.",
    threshold = 15, -- damage taken per spray (post-mitigation)
    radius = 2,     -- how far a spray reaches from the body
    spray = 6,      -- the flat pierce blow each quill carries, before mitigation
    onDamaged = function(ctx)
        local u = ctx.unit
        local amount = ctx.amount or 0
        if amount <= 0 or not (u and u.alive) then return end
        local threshold = ctx.param("threshold", 15)
        local bank = (ctx.trait.banked or 0) + amount
        local sprays = math.floor(bank / threshold)
        ctx.trait.banked = bank - sprays * threshold
        if sprays <= 0 then return end
        -- One blow that banks two sprays throws two -- but never more than the status can hold, so a
        -- giant's single swing does not stack a whole front line to the cap in one beat.
        sprays = math.min(sprays, 2)
        local radius, spray = ctx.param("radius", 2), ctx.param("spray", 6)
        local struck = 0
        for _, other in ipairs(ctx.unitsNear(u.x, u.y, radius)) do
            if other.alive and other.side ~= u.side then
                for _ = 1, sprays do
                    if not other.alive then break end
                    ctx.damage(other, spray, { "physical", "pierce", "quill" })
                    if other.alive then ctx.applyStatus(other, "status_quilled") end
                end
                struck = struck + 1
            end
        end
        if struck > 0 then
            ctx.log("action", string.format("%s bristles, and quills fly.", (u.char and u.char.name) or "It"))
        end
    end,
}
