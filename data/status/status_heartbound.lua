-- Heartbound: a body whose life is kept somewhere else -- in a tree standing on the same board.
--
-- WHILE THE TREE STANDS, NOTHING KILLS ITS BEARER. The flag is Not Yet's (`preventsDeath`,
-- Status.preventsDeath -- Combat.dealFlatDamage floors the bearer at 1), and the difference from Not Yet
-- is the clock: this one has none. It ends when the tree does. The tree is stamped on the status as
-- `tree` when it lands (the applier), and every tick asks after it.
--
-- AND A BLOW THAT FLOORS IT SENDS IT HOME. Brought to 1, the bearer steps back into the grain -- it is
-- set down on a free tile beside its tree, out of the reach of whoever was killing it. That is the
-- Hamadryad's fight in one line: the thing to cut is not the body in front of you, it is the tree it
-- keeps running back to (data/characters/character_hamadryad.lua).
--
-- `magnitude` is how many times it may do that, and nil means without limit. The Hamadryad's own bond
-- has no limit; the Heartwood a company can carry out of that fight (utility_heartwood) holds once.
return {
    name = "Heartbound",
    abbr = "Hrt",
    description = "Cannot be killed while its tree stands: a killing blow leaves it at 1, beside the tree.",
    color = { 0.431, 0.580, 0.345 }, -- badge tint (heartwood green)
    duration = 9999,              -- no clock: the tree is the clock
    preventsDeath = true,         -- Status.preventsDeath: floored at 1
    onApply = function(ctx)
        if ctx.status.tree == nil then ctx.status.tree = ctx.applier end
    end,
    onTick = function(ctx)
        local tree = ctx.status.tree
        if not (tree and tree.alive) then ctx.expire() end
    end,
    onDamaged = function(ctx)
        local tree = ctx.status.tree
        if not (tree and tree.alive) then ctx.expire() return end
        local hp = ctx.unit.char.stats.health
        if hp.current > 1 then return end
        local Combat = require("models.combat")
        local x, y = Combat.openTileNear(ctx.combat, tree.x, tree.y)
        if x then
            ctx.log("status", string.format("%s steps back into the grain.",
                (ctx.unit.char and ctx.unit.char.name) or "Unit"))
            Combat.teleportUnit(ctx.combat, ctx.unit, x, y, { silent = true })
        end
        if ctx.status.magnitude then
            ctx.status.magnitude = ctx.status.magnitude - 1
            if ctx.status.magnitude <= 0 then ctx.expire() end
        end
    end,
}
