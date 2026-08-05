-- On Account: while it stands, the bearer's wounds are BILLED rather than borne. Every blow that gets
-- past armor is settled out of the purse instead of the flesh -- five coins to the point, up to a cap
-- per blow -- and anything past that cap, or anything the bank cannot afford, lands as an ordinary
-- wound (Combat.soakIntoPurse, run just past mitigation in the damage core).
--
-- The reusable half of The Open Account (data/items/ability/ability_open_account.lua), which toggles
-- this on and off. Anything else that wants the rule -- a relic lifted off Aurea, a cursed contract,
-- the general of Greed's own gold ward (docs/story.md, "The gold, in numbers": damage dealt into her
-- gold, not her flesh) -- applies this same status and gets the same arithmetic, the same badge and
-- the same log line for free. Combat.spendPurse is side-aware, so an enemy wearing this spends its
-- own coffer and never touches the player's bank.
--
-- WHY THE RATE LIVES HERE AND THE CAP DOES NOT. `paysInGold` is the exchange rate -- what a point of
-- harm costs in coin -- and it is the same rate wherever the rule turns up, so it belongs to the rule.
-- `magnitude` is how much of a single blow the account will cover, and that is what an individual
-- granter tunes (the ability raises it per forge level); the 10 here is the floor a bare application
-- gets when nobody says otherwise. Same division of labour as Physical Barrier, whose `negates` names
-- the school it eats while its `magnitude` counts the blows -- and for the same reason: the rule is not
-- a growth axis, the coverage is.
--
-- WHY THE CAP EXISTS AT ALL. Without one, a fat purse is simply a second health bar, and the correct
-- play becomes standing your softest body in front of a boss's alpha strike and paying it off. Capping
-- what one blow may bill makes this a ward against ATTRITION -- the twenty small wounds a fight
-- actually deals -- and no defence whatever against the one enormous hit, which is exactly the shape
-- greed should have: it buys off the ordinary and cannot buy off the extraordinary.
--
-- WHY IT IS NOT A DEBUFF, the same call status_magic_denied makes and for a near-identical reason:
-- `debuff = true` would put it in Cure's and Panacea's reach, and a bearer whose own toggle can be
-- washed off by an ally's cleanse is a bearer who cannot rely on it. It states what it is -- a
-- condition the bearer chose and can un-choose -- so only the toggle (or death) closes it.
--
-- The duration is the battle: an account is open until it is closed, so there is no tick count to
-- carry, and math.huge survives Status.tick's countdown unchanged (huge minus elapsed is huge). The
-- badge stands the whole time on purpose -- a player whose gold is quietly draining every time
-- somebody swings at this unit deserves to be told why, every turn -- and `hideDuration` keeps it from
-- pretending to count down to anything.
return {
    name = "On Account",
    abbr = "Acct",
    description = "Billed, not borne: wounds are settled out of the purse at 5 gold a point.",
    color = { 0.811, 0.700, 0.335 }, -- badge tint (coin gold -- the Struck Ledger's own, greed's colour)
    duration = math.huge,            -- open until it is closed; see the note above
    hideDuration = true,             -- there is no countdown to show, and "inf" ticks is worse than none
    magnitude = 10,                  -- points of a SINGLE blow the account covers; the granter raises it
    paysInGold = 5,                  -- gold per point of the wound it settles (Combat.soakIntoPurse)
}
