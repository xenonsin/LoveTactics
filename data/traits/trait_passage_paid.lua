-- PASSAGE PAID: Mora's second rule (data/characters/character_mora.lua; models/toll.lua, Toll.passage). A body that
-- spends a whole turn doing nothing on a gate tile -- any tile edge-on to her -- is let through and leaves the board
-- safe. If every living body of the company passes, the fight is won without her falling (Toll.passedThrough, read
-- by Combat.outcomeFor), but she pays her drop only if she falls.
--
-- "Doing nothing" is read off the turn itself: where the body stood as its turn opened (onAnyTurnStart), whether it
-- used anything (onAnyCast), and whether it stepped (the turn record) -- so a Wait, a Defend or a turn passed all
-- pay, and a turn a Stun took from it does not.
--
-- `passagePaid` is the flag Toll.passage reads to withhold her drop when the last body goes through.
return {
    name = "Passage Paid",
    description = "A foe that does nothing for a whole turn beside it passes through and leaves the board.",
    passagePaid = true,
    notAReaction = true,
    onAnyTurnStart = function(ctx)
        require("models.toll").noteTurn(ctx.combat, ctx.actor)
    end,
    onAnyCast = function(ctx)
        require("models.toll").noteAct(ctx.combat, ctx.caster)
    end,
    onAnyTurnEnd = function(ctx)
        require("models.toll").passage(ctx.combat, ctx.unit, ctx.actor)
    end,
}
