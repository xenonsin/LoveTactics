-- THE BARRIER: the Bailiff's rule, and its drop's (models/toll.lua, Toll.barrier). A brace that covers every ally
-- beside it until the holder's own next turn -- stamped `heldBy` on the lent brace, which status_defending honours.
--
-- Two readings of one rule, told apart by the granter's params:
--   always = true, kin = true   the Bailiff (utility_the_barrier): it braces at the end of EVERY turn, and covers
--                               every Tollkeeper beside it. An AI body never presses Defend (models/ai.lua ends a
--                               waiting turn in Combat.pass), so its stance is its rule rather than its choice.
--   (defaults)                  the Bailiff's Bar (armor_bailiffs_bar): a turn that ended in Defend lends the brace
--                               to every adjacent ally.
-- The lent braces come down as the holder's next turn opens. An impact blow on a braced Tollkeeper breaks it
-- (trait_barred), and on the Bailiff breaks every brace it lent.
return {
    name = "The Barrier",
    description = "Its brace covers every ally beside it until its next turn.",
    covers = 6,
    notAReaction = true,
    onTurnStart = function(ctx)
        require("models.toll").release(ctx.combat, ctx.unit)
        -- The stamp a brace raised THIS turn is measured against (Toll.barrier).
        ctx.unit._barrierSerial = (ctx.combat and ctx.combat._statusSerial) or 0
    end,
    onTurnEnd = function(ctx)
        require("models.toll").barrier(ctx.combat, ctx.unit, {
            always = ctx.param("always", false), kin = ctx.param("kin", false),
            covers = ctx.param("covers", 6), brace = ctx.param("brace", nil),
        })
    end,
}
