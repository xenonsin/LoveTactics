-- SPLITTING: the first time it drops to half health, a weaker copy of it steps out beside it. Once a
-- fight. The copy is its bare blueprint at half its health ceiling -- the Comes Apart rule
-- (data/traits/trait_split.lua) with one piece and a threshold instead of a death -- and a REAL body
-- (summoned = false), so a kill-all is not won over its head.
--
-- A script rather than a reflex (`notAReaction`): a stunned body still splits at half, as a boss still
-- turns at its threshold (Trait.onDamaged says why).
return {
    name = "Splitting",
    description = "At half health, a weaker copy of it steps out beside it, once.",
    mark = "D",
    color = { 0.45, 0.85, 0.55 },
    notAReaction = true,
    onDamaged = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive and unit.char) then return end
        if (ctx.trait.stacks or 0) > 0 then return end
        local hp = unit.char.stats and unit.char.stats.health
        if type(hp) ~= "table" or (hp.max or 0) <= 0 then return end
        if hp.current * 2 > hp.max then return end
        ctx.trait.stacks = 1
        local x, y = ctx.openTileNear(unit.x, unit.y)
        if not x then return end
        local copy = ctx.summon(unit.char.id, x, y, {
            summoner = false, summoned = false, announce = false, noClaim = true,
            stats = { health = math.max(1, math.floor(hp.max / 2)) },
        })
        if copy and copy.alive then
            ctx.log("action", string.format("%s splits in two.", unit.char.name or "It"), unit)
        end
    end,
}
