-- Surge: act again, right now, before anything else on the field gets a beat.
--
-- The first user of Combat.grantExtraAction, which is deliberately a GENERIC facility rather than
-- anything this file owns. An extra action is a fact about a unit -- when its action would end the
-- turn, the turn re-opens instead -- so a fighter's ability, a relic's trait and a boss phase all
-- reach for the same three lines and none of them needs to know about the others. This item is the
-- first thing to ask; it will not be the last.
--
-- WHAT IT BUYS IS ORDER, NOT TIME, and that is worth being exact about because the difference is the
-- whole design. Every tick the surged action would have cost is banked and paid in full the moment the
-- unit finally stops (see endTurn), so a fighter who swings twice lands correspondingly further down
-- the timeline: it has spent tomorrow's turn today. There is no free lunch here and there cannot be --
-- initiative is the only currency this game actually has, and an action genuinely free of it would let
-- a unit act, keep initiative 0, and act forever.
--
-- What the player gains instead is real, and it is the thing burst damage has always been for: two
-- actions with no enemy beat between them. A foe on 30 health that would have answered a 20-point
-- swing does not answer two of them. Surge does not make the fighter stronger over a long fight -- over
-- a long fight it makes it slightly weaker -- it decides short ones.
--
-- It grants no second WALK (endTurn re-opens the turn with `moved` already spent), so the fighter
-- swings twice from where it is standing. Closing the distance is still a turn.
--
-- Costs a real bite of stamina and effectively no tempo of its own (speed 1): the price is the banked
-- cost of whatever you do next, not this. Once per turn is enforced by arithmetic rather than a rule --
-- surging again would need another full action, and the surge you are spending is that action.
return {
    name = "Surge",
    description = "Act again immediately. The time it costs is paid when you finally stop.",
    flavor = "The pause between two blows is where most people decide to stop. He has removed the pause.",
    sprite = "assets/items/ability_charge.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "impact" },
    class = "fighter",
    price = 420,
    repRank = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 1,      -- the tempo cost is the NEXT action's, banked; this one is a breath
        support = true, -- it lands no damage
        cost = { stat = "stamina", amount = 12 },
        effect = function(fx)
            fx.grantExtraAction(1)
        end,
    },
}
