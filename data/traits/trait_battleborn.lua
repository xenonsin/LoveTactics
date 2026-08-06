-- Battleborn: fell something that nobody had softened for you, and the turn is handed back.
--
-- Fires when a foe drops on the bearer's own turn bearing NO debuff -- nothing bled it, marked it,
-- rooted it, halted it or crippled it first. It went down to the blow and to nothing else, and the
-- warlord has not finished (Combat.grantExtraAction).
--
-- THE EXACT MIRROR OF THE POACHER'S, on purpose. trait_thrill_of_the_hunt hands back a turn for
-- finishing a foe you had set up a turn earlier, and it is the hunter's because setup-then-payoff is
-- what that shelf IS. This is the fighter's answer, and wrath's claim is the opposite one: it happens
-- directly in front of you, and it does not need arranging. Two items, one mechanism, opposite
-- conditions -- which is a cheaper way to give two shelves an identity than two mechanisms would be.
--
-- WHY NOT OVERKILL, which is what this is borrowed from. The original reads "the first time each turn
-- this unit overkills an enemy by 10+ damage, refresh their turn". This codebase records no overkill
-- figure and no pre-hit health: by the time any death hook runs, the body is at 0 and what it had a
-- moment ago is gone. Inventing a damage-history record to serve one item is the wrong order of
-- operations -- so the claim is restated in something the board still holds at the moment of asking.
-- "Nothing had worn it down" is the same sentence as "you ended it before it was ever hurt", said in a
-- currency that exists.
--
-- ONCE PER TURN (Combat.firstThisTurn), for the same reason its mirror is: the granted action can fell
-- another unsoftened body, and a warlord in a fresh line would never stop. The stamp clears in
-- Combat.startTurn and survives the re-opened turn -- a surge re-enters combat.turn straight from
-- endTurn -- so once per turn means once per REAL turn.
return {
    name = "Battleborn",
    description = "Felling a foe that nothing had weakened hands your turn back, once a turn.",
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not fallen then return end
        if fallen.side == ctx.unit.side then return end          -- your own dead are not a victory
        local turn = ctx.combat and ctx.combat.turn
        if not (turn and turn.unit == ctx.unit) then return end   -- only on the bearer's own turn
        -- Anything softened it and the claim fails. Read off the status's own `debuff` flag rather
        -- than a list of ids, so a debuff authored next year counts without editing this file --
        -- and so a foe wearing its OWN buffs still qualifies, which is the right reading: a warlord
        -- cutting down something that was blessed and hale is more of the boast, not less.
        for _, s in ipairs(fallen.statuses or {}) do
            if s.def and s.def.debuff then return end
        end
        local Combat = require("models.combat")
        if not Combat.firstThisTurn(ctx.unit, "battleborn") then return end
        Combat.grantExtraAction(ctx.unit, 1)
        ctx.log("action", string.format("%s does not wait to be told.",
            (ctx.unit.char and ctx.unit.char.name) or "The warlord"))
    end,
}
