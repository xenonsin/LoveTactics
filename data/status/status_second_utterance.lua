-- Second Utterance: one spell in hand that needs no winding. While this holds, the next CHANNELED
-- ability the bearer casts resolves immediately instead of telegraphing -- Combat.useItem's channel
-- branch spends the charge and falls straight through to resolveCast, so the spell lands on the turn it
-- was spoken and bills its ordinary `speed` rather than its wind-up.
--
-- Granted by data/traits/trait_second_utterance.lua the moment one of the bearer's channels LANDS. Not
-- when a channel begins and not when one is interrupted: the charge is paid for by a spell that actually
-- resolved, which is what stops it from being a free opener.
--
-- It is spent by the FIRST channeled cast and by nothing else -- an unchanneled Fire Bolt walks past it
-- untouched (the check sits inside the channel branch, so there is nothing there to consume it). That is
-- deliberate and it is the whole tactical shape: the charge is worth exactly one big spell, so wasting
-- it on a small one is a mistake the model refuses to let you make.
--
-- A BUFF, so Cure leaves it be. It DOES have a clock, though, and that is not decoration: a charge that
-- kept until the end of the fight would let a mage bank one at leisure and open the next engagement with
-- an un-telegraphed Meteor Storm. Two turns is long enough to use it in the exchange that earned it and
-- too short to carry it into the next one.
return {
    name = "Second Utterance",
    abbr = "2nd",
    description = "Your next channeled spell resolves at once, with no wind-up.",
    color = { 0.62, 0.55, 0.92 }, -- badge tint (arcane violet, matching Graven and the Arcanum)
    duration = 12, -- ~2 turns at Status.TICKS_PER_TURN: the exchange that earned it, and not the next
}
