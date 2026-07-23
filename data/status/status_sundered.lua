-- Sundered: every standing thing the bearer owns goes quiet. Not a wound, not a rattling -- the
-- relics themselves stop answering. While it holds, models/trait.lua's dispatch refuses EVERY trait
-- hook on this unit (Status.traitsDisabled), so the parry does not parry, the thorns do not bite, the
-- guard does not take the blow meant for the ally beside it, the last stand does not stand, and the
-- death rattle does not rattle.
--
-- THE GAP IT FILLS. This game has forty-odd traits and, until this, nothing at all that answered one.
-- A build whose entire strength is its passives -- a knight ringed in guard redirects, an armored
-- thorns-and-riposte wall -- could be out-damaged but never out-PLAYED, because there was no move that
-- addressed the reason it was strong. Sundering is that move. It costs a whole action and lands on one
-- body, so it does not erase a strategy; it opens a window in one.
--
-- Deliberately NOT `disablesReactions` (Stun, Frozen), and the distinction is the whole point. That
-- flag is a body too rattled to answer, and it lets onStatusApplied through on purpose so a cleansing
-- ward can still shrug off the very stun that landed. This takes that hook too -- a sundered relic
-- cannot ward against its own sundering -- which is exactly what a break has to be able to do, and
-- exactly why it could not be expressed as a stronger reading of the old flag.
--
-- Priced as an affliction rather than a position: it is a DEBUFF (a Cure lifts it), it is resistible
-- on the magical school, and its diminishing returns are the same as everything else's -- the second
-- sundering of the same body this battle buys half as long, and the fourth buys nothing. A build
-- cannot be kept switched off; it can be switched off once, at the moment it mattered.
return {
    name = "Sundered",
    abbr = "Sund",
    description = "Sundered: every trait, guard and reflex it carries is silent.",
    color = { 0.42, 0.38, 0.44 }, -- badge tint (dead grey-violet: a thing gone quiet)
    duration = 12,                -- ~2.5 turns: a window, never a removal
    debuff = true,
    resistible = "magical",
    disablesTraits = true,
}
