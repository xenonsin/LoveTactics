-- SCURRY: the Kobold Skulker's footwork, and its drop (data/items/utility/utility_scurry.lua). Round 2
-- (2026-09-25), on Keno's note on the round-1 drop: "Too similar to wolf, I like it but add something".
--
-- THE STEP BACK is In and Out's own flag (`givesGround`, trait_in_and_out): after a melee blow the bearer
-- steps a tile out of reach, on its own turn and when it answers. What is ADDED is HARRY: the foe it
-- landed that blow on is left Harried (status_harried, -3 Defense until the next blow lands on it). So the
-- disengage is a setup for whoever acts next, which is how a kobold pack fights and not how a wolf does.
--
-- On onCast, after the swing has resolved and the step has been taken -- a blow that drew no blood harries
-- nobody (the rule weapon_petal_touch's charm was authored out of), and only a MELEE blow counts, since
-- only a melee blow gives ground.
return {
    name = "Scurry",
    description = "After a melee blow, step back one tile, and the foe you struck is Harried.",
    givesGround = 1,
    onCast = function(ctx)
        if (ctx.damageDealt or 0) <= 0 then return end
        local cast = ctx.item -- the weapon that just swung (see trait_stooping_blow on this shadowing)
        if not (cast and cast.activeAbility) then return end
        local melee = false
        for _, tag in ipairs(cast.tags or {}) do
            if tag == "melee" then melee = true break end
        end
        if not melee then return end
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        ctx.applyStatus(target, "status_harried", { applier = ctx.unit })
    end,
}
