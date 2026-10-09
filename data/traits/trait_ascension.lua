-- ASCENSION: the Champion's piece taken off the Archon Duke (data/items/utility/utility_ascension.lua; "The Crown's
-- Bestiary", slice A, 2026-10-09). The Duke Ascends on the wisps of its own court; carried out, the bearer Ascends on
-- the foes it downs. Each foe it fells is a stack, and at the third it Ascends for the rest of the fight: +6 Damage
-- and +2 Movement.
--
-- Reads the killer off `lastAttacker`, which killUnit stamps (the Culler's Kit's way), and counts only a foe that was
-- a body -- a summon winking out is not one. Banked through ctx.addBonus, so it drains away with the battle.
return {
    name = "Ascension",
    description = "Each foe you down gives a stack. At 3 you Ascend for the fight: +6 damage and +2 movement.",
    maxStacks = 3,
    onAnyDeath = function(ctx)
        local fallen, u = ctx.fallen, ctx.unit
        if not (fallen and u.alive) or fallen.side == u.side or fallen.lastAttacker ~= u then return end
        if fallen.summoned then return end
        local cap = ctx.def.maxStacks or 3
        if ctx.trait.stacks >= cap then return end
        ctx.trait.stacks = ctx.trait.stacks + 1
        if ctx.trait.stacks < cap then return end
        ctx.addBonus("damage", ctx.param("damage", 6))
        ctx.addBonus("movement", ctx.param("movement", 2))
        ctx.log("action", string.format("%s Ascends.", (u.char and u.char.name) or "Unit"))
    end,
}
