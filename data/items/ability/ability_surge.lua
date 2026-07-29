-- Surge: act again, right now, before anything else on the field gets a beat.
--
-- The first user of Combat.grantExtraAction, which is deliberately a GENERIC facility rather than
-- anything this file owns. An extra action is a fact about a unit -- when its action would end the
-- turn, the turn re-opens instead -- so a fighter's ability, a relic's trait and a boss phase all
-- reach for the same three lines and none of them needs to know about the others. This item is the
-- first thing to ask; it will not be the last.
--
-- IT IS A FREE ACTION (ab.free -- the Battle Tonic pattern in docs/classes.md), and that is the whole
-- fix: a free cast bills no initiative and does NOT close the turn, so it is an EXTRA taken between doing
-- things, leaving your normal action untouched. Surge itself does nothing but grant -- if it also ended
-- the turn (any ordinary active does), the endTurn that closed it would immediately spend the very extra
-- action it just granted, and the surge would refund the action it cost and net you nothing. Free is
-- what lets you keep your swing AND take the granted one: two blows, in that order, with no enemy beat
-- between them.
--
-- WHAT IT BUYS IS ORDER, NOT TIME, and that is worth being exact about because the difference is the
-- whole design. Surge the breath is free, but the two swings are not: every tick each one costs is
-- banked and paid in full the moment the unit finally stops (Combat.grantExtraAction / see endTurn), so
-- a fighter who swings twice lands correspondingly further down the timeline -- it has spent tomorrow's
-- turn today. There is no free lunch in the SWINGS and there cannot be -- initiative is the only currency
-- this game actually has, and an action genuinely free of it would let a unit act, keep initiative 0, and
-- act forever. What is free is only the ordering breath, and that is bounded a different way (below).
--
-- What the player gains is real, and it is the thing burst damage has always been for: two actions with
-- no enemy beat between them. A foe on 30 health that would have answered a 20-point swing does not
-- answer two of them. Surge does not make the fighter stronger over a long fight -- over a long fight the
-- banked tempo makes it slightly weaker -- it decides short ones.
--
-- The granted action grants no second WALK (endTurn re-opens the turn with `moved` already spent), so
-- the second blow lands from where the first left the fighter. Closing the distance is still a turn.
--
-- Costs a real bite of stamina. Once per turn is enforced by the free-action limit
-- (Combat.FREE_ACTIONS_PER_TURN, one per turn), not by the tempo -- a zero-tempo action needs a hard
-- ceiling or it loops, which is exactly what `free` provides.
return {
    name = "Surge",
    description = "A free action: keep your turn and act once more, back to back. The extra swing's time is paid when you finally stop.",
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
        speed = 0,      -- a free breath bills no tempo of its own (cf. consumable_battle_tonic)
        free = true,    -- bills no initiative and leaves the turn open, so the grant is an EXTRA, not a swap
        support = true, -- it lands no damage
        cost = { stat = "stamina", amount = 12 },
        effect = function(fx)
            fx.grantExtraAction(1)
        end,
    },
}
