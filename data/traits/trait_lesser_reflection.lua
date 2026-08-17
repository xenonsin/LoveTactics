-- LESSER REFLECTION: Envy's rule, one rank down, and the mechanic the desert circle is built on.
--
-- Livia's Covetous Reflection looks across the field at the OPENING BELL, finds the unit that towers,
-- and stands a copy of it on her own side (data/traits/trait_covetous_reflection.lua). Meeting that
-- cold is a fight you have already lost the read on: your best body is suddenly on the wrong side and
-- you were never given a turn in which to prevent it.
--
-- So the honour-guard floor teaches it twice as cheaply and in the opposite direction. This takes the
-- WEAKEST body it can see, and only once it has been hurt -- so the copy arrives late, arrives small,
-- and arrives after the player has had several turns to notice what the circle is about. Then the stair
-- goes down and Livia takes the best one before anybody has moved.
--
-- WHICH BODY IS WEAKEST IS SOMETHING THE PLAYER CONTROLS, and that is the whole reason the swarm beside
-- this exists. Glass-Motes strip buffs (data/characters/character_glass_mote.lua), so the party's own
-- shape decides what gets copied -- protect a body and it stops being the cheapest thing on the board.
-- Envy's counterplay in Livia's own header is "do not let one unit tower"; here it is the mirror of
-- that, and both are decisions about the SHAPE of a company rather than about a stat.
--
-- Fires from onDamaged rather than onCombatStart, which is what makes it a phase rather than an opening.
-- `once` is tracked on the trait's own stacks so a long fight cannot fill the board with reflections.
return {
    name = "Lesser Reflection",
    description = "Once wounded, it takes the shape of the weakest foe, and it fights for the mirror.",
    at = 0.5, -- the share of health it has to be cut past before the mirror answers
    onDamaged = function(ctx)
        local u = ctx.unit
        if not (u and u.alive) then return end
        if (ctx.trait.stacks or 0) > 0 then return end -- one reflection, ever

        local hp = u.char.stats.health
        if not hp or hp.max <= 0 then return end
        if (hp.current / hp.max) > (ctx.def.at or 0.5) then return end

        -- The LEAST of them, which is the deliberate inverse of Livia's reading. Copies are skipped for
        -- her reason: a reflection of a reflection is a runaway, not a fight.
        local worst, worstScore
        for _, other in ipairs(ctx.combat.units) do
            if other.alive and other.side ~= u.side and not other.summoned then
                local s = other.char.stats
                local score = (s.health and s.health.current or 0) + (s.damage or 0) + (s.magicDamage or 0)
                if not worstScore or score < worstScore then worst, worstScore = other, score end
            end
        end
        if not worst then return end
        local x, y = ctx.openTileNear(u.x, u.y)
        if not x then return end

        ctx.trait.stacks = 1
        ctx.copyOf(worst, x, y)
        ctx.log("system", string.format("%s finds a shape it can manage: %s.",
            (u.char and u.char.name) or "It", (worst.char and worst.char.name) or "the least of you"))
    end,
}
