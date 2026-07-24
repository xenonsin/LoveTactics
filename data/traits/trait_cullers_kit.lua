-- Culler's Kit: the standing rule of the Herbalist's charm. An enemy the bearer fells leaves a reagent
-- in the bearer's satchel.
--
-- Hangs on onDeath's broadcast twin (onAnyDeath) and asks the two questions Distil does not: was it a
-- foe, and did the bearer kill it. The hunter kills it, the alchemist renders it down -- which is the
-- literal fusion, and the reason this replaced a Forager's Satchel that read hazards and therefore did
-- the same job as Distil twice.
--
-- Reads the killer off `lastAttacker`, which killUnit already stamps. So it pays out on any kill by any
-- means -- an arrow, a poison tick, a trap, a summoned wolf's teeth -- rather than only on a weapon
-- swing, which is right for a discipline whose whole idea is that the fight itself is the ingredient.
--
-- Silent on a full grid: Combat.grantItem logs the refusal itself, and a charm that shouted about a
-- satchel with no room every time something died would be unbearable in a long fight.
return {
    name = "Culler's Kit",
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not (fallen and ctx.unit.alive) then return end
        if fallen.side == ctx.unit.side then return end
        if fallen.lastAttacker ~= ctx.unit then return end
        if fallen.summoned then return end -- a conjuration renders down to nothing; it was never there
        local Combat = require("models.combat")
        Combat.grantItem(ctx.combat, ctx.unit, "consumable_wildcraft_reagent")
    end,
}
