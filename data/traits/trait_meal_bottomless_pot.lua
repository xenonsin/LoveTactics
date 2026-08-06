-- The Bottomless Pot: the kitchen skill on the Cafe's caster order. Every battle of the quest opens
-- with mana back in the pool -- the pot the counter keeps topping up, all the way out and back.
--
-- MANA DOES NOT REGENERATE IN THIS GAME. That is the hard rule the whole caster economy is built on
-- (see data/items/consumable/consumable_wellspring_sandals.lua), and it is what makes this the single
-- most valuable thing a supper can do for a party with two casters in it: wounds carry between the
-- fights of a run, and so does a spent mana pool. A mage who arrives at the objective empty has been
-- out of the fight since the third node.
--
-- Monster Hunter's Felyne Booster read through that rule. There, food that stretches your consumables
-- is a convenience; here, the resource it stretches is the one nobody gets back, so the same idea comes
-- out considerably sharper than it went in.
--
-- Fires on `onCombatStart`, which is once per BATTLE and therefore several times per quest -- that is
-- deliberate and is where the value is. It is not a heal: it pours into a pool through ctx.restore
-- (Combat.restoreResource), capped at the drinker's own ceiling, so a member who walked in full gains
-- nothing and the order is honestly a bad one for a party of fighters. The menu text says so.
--
-- Silent for a body with no mana at all rather than logging a line about nothing: at MAX_FIELD 4, half
-- a typical company would otherwise open every fight with a message saying it got nothing.
return {
    name = "The Bottomless Pot",
    description = "Opens every battle of the quest with mana restored.",
    amount = 12,
    onCombatStart = function(ctx)
        local pool = ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.mana
        if type(pool) ~= "table" or (pool.max or 0) <= 0 then return end
        local given = ctx.restore(ctx.unit, "mana", ctx.def.amount or 12)
        if given > 0 then
            ctx.log("action", string.format("%s starts the fight on this morning's pot (+%d mana).",
                (ctx.unit.char and ctx.unit.char.name) or "Unit", given), ctx.unit)
        end
    end,
}
