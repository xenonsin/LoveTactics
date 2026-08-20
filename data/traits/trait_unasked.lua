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
-- Reads Combat.heldItsTurn, which answers off the turn's spend tally combat opens at every turn start
-- and adds to at every payment out of a pool (models/combat.lua, spendResource). A body that has not
-- had a turn yet has an unopened tally and is passed over rather than guessed at: it has not held
-- anything back, it has never been asked.
--
-- The tally and not the pools. A body sitting at 0 stamina has spent everything it had, which is the
-- last thing this rule means to punish, and an empty pool cannot be told from one that was never
-- filled.
return {
    name = "The Unasked",
    description = "Draws off the stamina and mana of a foe that spent nothing and takes it into itself; once wounded, of any foe.",
    stamina = 8,
    mana = 8,
    -- IT STOPS ASKING below this fraction of its own health: the condition comes off and the rule is
    -- Luxuria's, met one floor early. Authored here rather than as a phase response because a trait
    -- cannot be granted mid-fight (data/traits/trait_boss_phases.lua carries no `trait` kind), and the
    -- alternative -- a lesser copy of Rapture bolted on at the threshold -- is the thing the whole tier
    -- is written against. Must match the relic's own phase threshold, which is what puts the line in the
    -- log and the bodies on the board at the same moment; tests/greed_lust_circle_spec.lua pins the two
    -- numbers together so they cannot drift apart into a boast the fight does not keep.
    stopsAskingBelow = 0.5,
    onCast = function(ctx)
        local target = ctx.unitAt(ctx.tx, ctx.ty)
        -- WHOSE the body is, not which side it is standing on. Its own touch Charms
        -- (data/items/weapon/weapon_petal_touch.lua), which moves the victim onto ITS side before this
        -- hook runs -- so a plain `side` test would have the Suppliant decline to drain the very body it
        -- just took. Status.ownSide reads through Charm's stash to the side the body belongs to.
        local Status = require("models.status")
        if not target or not target.alive
            or Status.ownSide(target) == Status.ownSide(ctx.unit) then return end
        -- A will that gave everything away holds nothing back to seize -- Amana's rule, honoured here
        -- exactly as Rapture honours it, so the one counter to the sin works on both its ranks.
        if require("models.trait").has(target, "trait_devotion_unbidden") then return end

        -- THE GATE. Only a body that came back around to act having paid out nothing is drained; one
        -- that spent is left alone. That is the whole difference from Luxuria, and it is what makes the
        -- rule something a player can learn from watching rather than from being told.
        --
        -- Unless it is far enough into its own dying to stop asking, at which point every body on the
        -- field is drained whatever it did with its turn -- and the player meets, on the honour-guard
        -- floor, the rule that waits at the bottom of the stair.
        local Combat = require("models.combat")
        local hp = (ctx.unit.char and ctx.unit.char.stats and ctx.unit.char.stats.health) or {}
        local left = (hp.max and hp.max > 0) and (hp.current or 0) / hp.max or 1
        if left > (ctx.def.stopsAskingBelow or 0) and not Combat.heldItsTurn(target) then return end

        local taken = ctx.drain(target, "stamina", ctx.def.stamina) + ctx.drain(target, "mana", ctx.def.mana)
        if taken > 0 then
            ctx.heal(ctx.unit, math.floor(taken / 2 + 0.5))
            ctx.log("action", string.format("%s takes what was never offered.",
                (ctx.unit.char and ctx.unit.char.name) or "It"))
        end
    end,
}
