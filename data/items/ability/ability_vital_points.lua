-- Vital Points: press somewhere on an ally that makes them able to go again.
--
-- THE ONE VERB THIS GAME COULD NOT SAY. `fx.grantExtraAction` has existed for a long time and was
-- hardwired to the caster -- an ability could hand ITSELF another swing and nothing could hand one to
-- anybody else. So the whole support ceiling was healing, warding and moving people; "let the best body
-- on the field act twice" was unauthorable. Widening that helper to take a target is the engine change
-- this item exists to spend, and it is the only genuinely new thing a priest has been given in a while.
--
-- WHAT IT ACTUALLY DOES, stated plainly because "refresh their turn" would be a lie on this timeline.
-- There are no action points here; initiative is the only currency, and a body whose turn is not open
-- has no turn to re-open. What the grant does is sit on the ally (`unit.extraActions`) and get spent by
-- endTurn, so the promise is: THEIR NEXT TURN CARRIES TWO ACTIONS INSTEAD OF ONE. That is a real thing
-- to give somebody. It is also why this pairs the grant with fx.hasten -- the extra action arrives, and
-- it arrives sooner, which between them is as close to "go again" as an initiative game gets.
--
-- BOUGHT WITH A POOL, not with mana. A second action for the party's heaviest hitter is the strongest
-- support effect in the catalog, and mana is a resource a priest simply has -- gating on it would make
-- this a button pressed on turn one of every fight. `focus` banks off the two things a priest is doing
-- anyway (healing and casting), so the acolyte earns it across the fight and spends it once, at the
-- moment they judge worth doubling. That is a decision; a cooldown would only have been a delay.
--
-- The pool is declared HERE, in the file that spends it, which is the rule (docs/classes.md: a spender
-- declares the pool it spends -- an item may not be another item's on-switch). A Theurge charm that
-- widens or deepens Focus is welcome to exist later; this works the day it is bought.
--
-- AIMED AT AN ALLY AND NEVER AT YOURSELF. Self-targeting would make it a strictly better Surge for a
-- caster who never needed one, and the whole point is that the value is in choosing WHOSE turn is worth
-- two. It cannot reach the dead or the Incapacitated either: a body on the downed countdown is not
-- short of an action, it is short of being alive.
return {
    name = "Vital Points",
    description = "An ally's next turn carries two actions instead of one, and comes sooner.",
    flavor = "Three fingers, just under the shoulder. She has never explained it and nobody has asked twice.",
    sprite = "assets/items/ability_vital_points.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "theurge", -- multiclass: stocked on the mage's shelf too once the gate is cleared
    price = 210,
    unlockQuests = 1,
    -- Banked off what a priest does anyway, so the acolyte arrives at the payoff whether the fight
    -- went well or badly. Capped, like every pool: a charge that grew all battle would make the last
    -- turn the only one that mattered (docs/classes.md).
    charge = { key = "focus", from = { "healDone", "cast" }, max = 10 },
    activeAbility = {
        target = "ally",
        range = 2,
        speed = 6,
        support = true, -- reads green: it lands no damage
        cost = { stat = "mana", amount = 8 },
        unlock = {
            when = function(unit) return require("models.combat").chargePool(unit, "focus") >= 5 end,
            text = "Bank Focus by healing and casting",
        },
        description = "Spend Focus: an ally's next turn carries two actions instead of one, and arrives sooner.",
        effect = function(fx)
            local ally = fx.target
            if not (ally and ally.alive) then return end
            if ally == fx.user or ally.side ~= fx.user.side then return end
            -- WHAT THE FORGE BUYS IS THE PRICE: ten Focus at level 0 down to five fully forged, so a
            -- well-kept commission spends the pool further rather than granting a bigger favour (an
            -- extra action cannot be granted harder). Authored off fx.level rather than as a Curve
            -- because a five-point fall cannot pay out once per forge level, and models/curve.lua is
            -- explicit that a magnitude with less climb than that is identity, not a growth axis --
            -- the same reason ability_stand_down derives its duration here instead.
            local price = math.max(5, 10 - math.floor(fx.level / 2))
            -- Through fx.spendCharge, never Combat.spendCharge: the damage preview replays this effect
            -- against an inert context, and a pool that emptied itself under the cursor is a bug that
            -- reads as one (docs/classes.md -- the rule the coatings follow). It returns what it
            -- actually TOOK, so a short pool is caught by comparing against the price rather than by
            -- truthiness -- 0 is true in Lua, and a bare `if not spend` would fire this for free.
            if fx.spendCharge("focus", price) < price then return end
            fx.grantExtraAction(1, ally)
            -- ...and sooner. A quarter off their wait, so the doubled turn is not three beats away.
            fx.hasten(ally, 0.25)
            fx.log("action", string.format("%s finds the point, and %s is not finished.",
                (fx.user.char and fx.user.char.name) or "The acolyte",
                (ally.char and ally.char.name) or "the ally"), ally)
        end,
    },
}
