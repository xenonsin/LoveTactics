-- Thrill of the Hunt: finish something you had already marked out, and you are not finished.
--
-- Fires on the death of a foe that was carrying one of the hunter's own set-up statuses -- Mark, Bleed,
-- Root or Cripple -- and hands the bearer's turn back (Combat.grantExtraAction: the turn re-opens
-- instead of ending, and the banked tempo settles when it finally does).
--
-- WHY IT IS GATED ON THE STATUS AND NOT ON THE KILL. Hunter's whole shelf is setup-then-payoff
-- (docs/classes.md), and the payoff half has always been damage -- a bigger number against a marked
-- body. This is the first item that pays in TEMPO, and gating it on the mark is what keeps it the
-- hunter's rather than a generic "kill to act again": a Poacher who spent a turn marking and a turn
-- shooting gets the third turn free, and one who simply walked up and shot something gets nothing.
-- The set-up is the price, paid a turn earlier.
--
-- ONCE PER TURN (Combat.firstThisTurn), which is not a balance dial but a termination condition. The
-- granted action can kill another marked body, which would grant another action, and a Poacher standing
-- in a line of bled foes would never stop. The stamp is cleared in Combat.startTurn and NOT by the
-- re-opened turn -- a surge re-enters combat.turn straight from endTurn without passing through
-- startTurn -- so "once per turn" means once per real turn, which is the promise the item makes.
--
-- It reads onAnyDeath, the one hook in this folder that is not about its own bearer, and checks that
-- the bearer is the one whose turn is open: a foe felled by a trap on somebody else's turn is not this
-- hunter's kill, and handing back a turn nobody is standing in would do nothing anyway.
local MARKS = { "status_mark", "status_bleed", "status_root", "status_cripple" }

return {
    name = "Thrill of the Hunt",
    description = "Felling a foe you had Marked, Bled, Rooted or Crippled hands your turn back, once a turn.",
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not fallen then return end
        if fallen.side == ctx.unit.side then return end          -- your own dead are not a hunt
        local turn = ctx.combat and ctx.combat.turn
        if not (turn and turn.unit == ctx.unit) then return end   -- only on the bearer's own turn
        local Combat = require("models.combat")
        local Status = require("models.status")
        local marked = false
        for _, id in ipairs(MARKS) do
            if Status.has(fallen, id) then marked = true break end
        end
        if not marked then return end
        if not Combat.firstThisTurn(ctx.unit, "thrill_of_the_hunt") then return end
        Combat.grantExtraAction(ctx.unit, 1)
        ctx.log("action", string.format("%s is already moving.",
            (ctx.unit.char and ctx.unit.char.name) or "The hunter"))
    end,
}
