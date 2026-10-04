-- BANKED TURNS: the ground sloths' rule (data/items/utility/utility_banked_turns.lua, utility_deep_bank.lua).
-- Approved 2026-10-04 on "Sloth's Bestiary", slice A.
--
-- Three halves, one per hook, all in models/sloth_beasts.lua:
--   * a turn the bearer ends without attacking is banked (status_banked), up to its own `cap` -- 3 on a Ground
--     Sloth, 5 on the Old Sloth. Its planner waits out any turn no foe is in its reach (`idlesUntilReach`, read by
--     AI.preempt), so "does nothing at all" is the turn the bank is earned on.
--   * a blow that lands on it knocks one turn out.
--   * the spend is the bearer's own weapon's business: the claws land once per banked turn and once more, the Old
--     Sloth's sweep goes round once per banked turn and once more.
-- `opensDormant` (the Old Sloth's) opens the fight Dormant with a full bank.
--
-- `notAReaction`: none of it is an answer to a blow, so a Stun or the Dormant sleep does not gag it -- the waking
-- blow still knocks a turn out.
local SlothBeasts = require("models.sloth_beasts")

return {
    name = "Banked Turns",
    description = "Banks each turn no foe is in reach. Its next attack lands once more per turn banked. A blow knocks one out.",
    notAReaction = true,
    idlesUntilReach = true,
    cap = 3,
    onCombatStart = function(ctx)
        local u = ctx.unit
        if not (u and u.alive and ctx.param("opensDormant", false)) then return end
        ctx.applyStatus(u, "status_dormant", { applier = u })
        require("models.bank").add(ctx.combat, u, ctx.param("cap", 3), ctx.param("cap", 3))
    end,
    onCast = SlothBeasts.markSwing,
    onTurnEnd = SlothBeasts.bankTurnEnd,
    onDamaged = SlothBeasts.knock,
}
