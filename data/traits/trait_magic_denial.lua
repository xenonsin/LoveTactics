-- Magic Denial: whoever carries this does not believe in magic, and lays the Magic Denied status on
-- themselves at the opening bell (data/status/magic_denied.lua) -- which is what actually shuts the
-- craft off for the rest of the fight.
--
-- The split is the reusability the effect is worth having: the TRAIT is "this item's wearer denies
-- magic", the STATUS is "this unit cannot work magic". Only the second is a rule the combat model
-- knows about, so anything at all can produce that state -- an enemy hex, a cursed relic, a dead-zone
-- arena -- by applying the same status, and it inherits the greyed-out slots, the tooltip note and the
-- badge without a line of new code. The armor is just the first thing to ask for it.
--
-- Laid at combat start rather than checked continuously, mirroring the other setup traits it sits
-- beside (Oathward and Martyr's Vow both plant their `unit.guard` here). The grid is fixed for the
-- duration of a battle, so "wearing it at the bell" and "wearing it" are the same statement.
return {
    name = "Magic Denial",
    description = "Magic isn't real. You cannot use it.",
    onCombatStart = function(ctx)
        ctx.applyStatus(ctx.unit, "status_magic_denied")
    end,
}
