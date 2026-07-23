-- Conjoined: bound into somebody else's body. While it lasts, every wound that lands on ANY unit in
-- the same conjunction is felt by every other one, at half strength (Combat.echoWound).
--
-- The runtime instance carries `.link` -- a bare table minted once per cast and stamped onto every
-- status that cast lands, exactly as Shout stamps `.taunter` and Shared Burden stamps `.bonded`. It is
-- what separates one working from another: without it, two conjunctions at opposite ends of the field
-- would feed each other. A status with no link does nothing at all, which is the correct behaviour for
-- a binding nobody performed.
--
-- READ IT AGAINST SHARED BURDEN (data/status/status_shared_burden.lua), because they are the same
-- machine with the sign flipped, and the difference is the two shelves arguing:
--
--   * The knight's bond CONSERVES. 40 damage becomes 20 and 20. It is sworn on an ALLY, it costs the
--     knight its own blood, and the total suffering in the world is unchanged -- only who carries it.
--     A promise.
--   * This AMPLIFIES. 40 damage becomes 40, and 20, and 20, and 20. It is laid on ENEMIES, it costs
--     the mage nothing but a turn, and it makes strictly more wound exist than there was before.
--     A working.
--
-- Sloth guards a body it can reach. Pride edits what a body IS, decides that four of them are now one,
-- and then goes back to its own business. Neither of them thinks the other's item is very impressive.
--
-- The struck unit takes its wound WHOLE -- the echo is added to the others rather than divided out of
-- it -- so a conjunction never softens the blow that triggers it. Each echo lands unmitigated (see
-- Combat.echoWound), which is the ability's answer to armor and the reason it is worth laying over
-- heavy infantry rather than over the same number of skirmishers.
--
-- A DEBUFF, so Cure strips it -- and that is the counter-play the ability is priced against. One
-- cleanse on one body takes that body out of the ring; it does not end the working for the rest.
return {
    name = "Conjoined",
    abbr = "Cnj",
    description = "Conjoined: takes half of every wound the others in the binding suffer.",
    color = { 0.58, 0.38, 0.72 }, -- badge tint (Arcanum violet -- the sigil ink)
    duration = 20, -- ~4 turns at Status.TICKS_PER_TURN: long enough to be worth setting up and spending
    debuff = true, -- removable by Cure, one body at a time
    resistible = "magical", -- a working, so a strong mind buys back some of the binding
    echoesDamage = 0.5, -- the share of another bound unit's wound this one feels
}
