-- THE BARE PATCH: the Godling's weakness (data/items/utility/utility_godlings_hunger.lua), approved as
-- pitched (2026-09-24) -- Smaug's belly and Bard's black arrow.
--
-- A CRITICAL HIT AGAINST THE GODLING KNOCKS OFF EVERY STACK OF GLUT AT ONCE. Everything its worshippers
-- gave it is gone in the one blow that finds the gap. On the SURVIVING hook (onDamaged), so a critical
-- that kills it has nothing left to strip; `notAReaction`, because a stunned Godling's belly is no less
-- bare. It is the mirror of the Hoard-Thane's Mithril Shirt, which no critical lands on: in Greed's two
-- elite fights, the crit build that does nothing against the Thane is the answer to the dragon.
return {
    name = "The Bare Patch",
    description = "A critical hit against you strips every stack of Glut.",
    notAReaction = true,
    onDamaged = function(ctx)
        if not ctx.critical then return end
        local Status = require("models.status")
        local unit = ctx.unit
        if Status.stacksOf(unit, "status_glut") <= 0 then return end
        Status.remove(ctx.combat, unit, "status_glut")
        ctx.log("action", string.format("The blow finds the bare patch: %s's glut falls away.",
            (unit.char and unit.char.name) or "the Godling"), unit)
    end,
}
