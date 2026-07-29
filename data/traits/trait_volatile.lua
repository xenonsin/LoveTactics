-- Volatile: the thing bursts when it dies. A self-destruct rule delivered as a trait so anything can
-- carry it -- a suicide-bomber demon (data/characters/character_demon_bomblet.lua via
-- data/items/utility/utility_volatile_core.lua), a powder keg, a corpse rigged to go off. On death it
-- deals a flat blast to everything in a small radius, friend and FOE alike (no side filter): you can
-- bait an enemy into its own bombs, and a clustered pack chain-reacts as each blast sets off the next.
--
-- This is the half that fires when SOMETHING ELSE does the killing. The Bomblet also carries the
-- deliberate half -- data/items/ability/ability_self_destruct.lua, a channeled cast that throws the
-- same ring on purpose -- and the two never double up, because that ability spends its caster through
-- fx.expendSelf (a dismissal, which fires no onDeath) rather than by killing it. A bearer that bursts
-- of its own accord has already burst; this hook is what answers a bearer that was cut down.
--
-- onDeath (not onDamaged): the blow that KILLS never fires onDamaged, so the burst has to hang off the
-- death itself. Trait.onDeath runs from killUnit before the field is unwound (see
-- data/traits/trait_blood_price.lua), so the blast lands with the bomber still on its tile. The
-- dispatch guards in models/trait.lua (unit._reacting per hook + MAX_DEPTH) keep a chain of bursts
-- from recursing forever.
--
-- Combat.dismiss does NOT fire onDeath: a bomber SUMMONED by a boss (the Champion's Roar) that vanishes
-- when the boss falls simply disappears -- it does not carpet-bomb the party on the boss's death. A
-- bomber that arrives as a plain reinforcement (the caravan-defense wave) is killed normally and bursts.
--
-- The blast is `damage` (mitigated, tagged fire), so armor and fire-resist read on it -- pop a bomber
-- at range and the blow never reaches you; kill one in your own teeth and you wear it.
return {
    name = "Volatile",
    description = "When it falls, it bursts -- everything nearby takes the blast.",
    magnitude = 12, -- blast power before mitigation
    radius = 1,     -- the ring the burst covers
    onDeath = function(ctx)
        local blast = ctx.def.magnitude or 0
        if blast <= 0 then return end
        -- The detonation READ, from the tile it fell on: the same ring the active half paints
        -- (data/items/ability/ability_self_destruct.lua), so a bomber cut down and a bomber that pulled
        -- its own pin look identical. Cosmetic; the blast damage is dealt in the loop below.
        ctx.burst(ctx.unit.x, ctx.unit.y, { "fire" })
        for _, u in ipairs(ctx.unitsNear(ctx.unit.x, ctx.unit.y, ctx.def.radius or 1)) do
            if u ~= ctx.unit and u.alive then
                ctx.damage(u, blast, { "fire" })
            end
        end
    end,
}
