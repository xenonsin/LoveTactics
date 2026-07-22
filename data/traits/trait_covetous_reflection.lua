-- Livia's rule, and Envy's in one hook: envy "has no shape until it has seen yours" (docs/story.md,
-- "The Crucible"). The homunculus that pacted for humanity got the power to copy any human perfectly and
-- never once to BE one -- she can be anyone and is no one. So at the opening bell she looks across the
-- field, finds the one unit that towers, and takes its shape onto her own side: your strongest, wearing
-- your face, fighting for her.
--
-- COPY, not fragile -- the completed Great Work the Crucible only ever sold you a fragile imitation of
-- (data/items/utility/utility_philosophers_stone.lua, whose own comment promises "it will point this
-- very ability at your strongest, and it will not be fragile then"). Same engine call (Summon.copyOf via
-- ctx.copyOf), opposite quality.
--
-- The counterplay is the sin read as tactics: do not let one unit tower, and she finds a lesser shape to
-- wear. Ren compresses the party upward into a flat, high plateau (data/items/utility/utility_aqua_vitae.lua)
-- so nothing stands far enough above the rest to be worth coveting.
--
-- SHIPPED FIDELITY: this is Covetous Reflection, the phase-one copy. The rest of her kit -- the Counterfeit
-- Host (blank homunculi that take a shape only once they SEE it), the Envious Pall, Covet and Grudge --
-- is deferred with her two-phase transform (see the chapter). Like every general's rule it travels with
-- the relic lifted off her body (data/items/utility/utility_envious_glass.lua): carry the Glass and you
-- open every fight wearing your strongest foe, and become the thing you killed.
return {
    name = "Covetous Reflection",
    description = "At the opening bell she takes the shape of the strongest foe on the field, and it fights for her.",
    onCombatStart = function(ctx)
        -- The one that towers on the OTHER side. Copies of copies are skipped (a summoned shape is not a
        -- self to covet), so she never mirrors her own reflection into a runaway.
        local best, bestScore
        for _, u in ipairs(ctx.combat.units) do
            if u.alive and u.side ~= ctx.unit.side and not u.summoned then
                local s = u.char.stats
                local score = (s.health and s.health.current or 0) + (s.damage or 0) + (s.magicDamage or 0)
                if not bestScore or score > bestScore then best, bestScore = u, score end
            end
        end
        if not best then return end
        local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
        if not x then return end
        ctx.copyOf(best, x, y) -- not fragile: the finished Work, not the puffer's imitation
        ctx.log("system", string.format("%s takes the shape of %s.",
            (ctx.unit.char and ctx.unit.char.name) or "She", (best.char and best.char.name) or "your strongest"))
    end,
}
