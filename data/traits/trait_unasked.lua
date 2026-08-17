-- THE UNASKED: Lust's rule, one rank down, and the mechanic the forest circle is built on.
--
-- Luxuria's Rapture draws off the stamina and mana a foe HELD BACK and takes it into herself
-- (data/traits/trait_rapture.lua) -- every hit, unconditionally, so a party that is husbanding resources
-- is feeding her and does not know it.
--
-- This asks first. It only drains a body that ended its turn having spent NOTHING, which makes the rule
-- legible in the one way Rapture is not: the player can see which of their units it fired on and work
-- backwards to why. Hold a turn and you are drained; spend and you are not.
--
-- WHICH IS A REAL DILEMMA RATHER THAN A TAX, because the circle's chaff is worthless to spend anything
-- on. The Petal-Drifts are there to make holding your good ability feel correct
-- (data/characters/character_petal_drift.lua), and the Suppliant is there to make it expensive. That
-- pairing is the whole floor.
--
-- Reads `unit.spentThisTurn`, which combat already tracks for the resource economy, and falls through to
-- draining nothing when the field is absent rather than guessing.
return {
    name = "The Unasked",
    description = "Draws off the reserves of a foe that spent nothing, and takes them into itself.",
    stamina = 8,
    mana = 8,
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        if not target or not target.alive or target.side == ctx.unit.side then return end
        -- A will that gave everything away holds nothing back to seize -- Amana's rule, honoured here
        -- exactly as Rapture honours it, so the one counter to the sin works on both its ranks.
        if require("models.trait").has(target, "trait_devotion_unbidden") then return end

        -- THE GATE. Only a body that held its turn is drained; one that spent is left alone. That is the
        -- whole difference from Luxuria, and it is what makes the rule something a player can learn from
        -- watching rather than from being told.
        local held = (target.char and target.char.stats) or {}
        local stam = held.stamina and held.stamina.current or 0
        local mana = held.mana and held.mana.current or 0
        if stam <= 0 and mana <= 0 then return end

        local taken = ctx.drain(target, "stamina", ctx.def.stamina) + ctx.drain(target, "mana", ctx.def.mana)
        if taken > 0 then
            ctx.heal(ctx.unit, math.floor(taken / 2 + 0.5))
            ctx.log("action", string.format("%s takes what was never offered.",
                (ctx.unit.char and ctx.unit.char.name) or "It"))
        end
    end,
}
