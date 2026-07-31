-- Grave-Cold: what a dead thing is, stated as a rule. Mending does not reach it -- a heal aimed at a
-- corpse burns it for the whole amount instead, from every source there is.
--
-- A FLAG, not a hook (Trait.flag): the interesting code is already written, at the one funnel every
-- mend in the game runs through (Combat.applyHeal, via Combat.healingInverted). What a dead body adds
-- is one clause at that seam, and a hook would have to re-derive who was healed and for how much --
-- which the mend already knows.
--
-- A TRAIT rather than a permanent status, for the reason models/trait.lua's header gives: a status is a
-- timed effect that ticks down and wears off, and this neither ticks nor wears. It is also the half of
-- the distinction that matters at the table -- Interred (data/status/status_interred.lua) is a curse
-- somebody spent a turn laying, and a Cure lifts it. This cannot be cured, because it is not an
-- affliction. It is the diagnosis.
--
-- WHAT IT COSTS THE PLAYER, which is the point of giving it to the zombie the MAGE RAISES rather than
-- only to the enemy dead. Raise Dead hands you bodies, and bodies in this game are things you keep
-- alive; this one is not. The party healer cannot spend a turn on it, and a Sanctified Presence or a
-- healing zone the line is standing in will quietly eat it. A raised corpse is a resource that burns
-- down on a timer and cannot be topped up -- which is what makes raising three of them a different
-- decision from recruiting one more soldier.
--
-- The tell is the preview: Combat.previewAbility asks the same question, so a heal aimed at a
-- grave-cold body previews in red, with the number it will actually take. Nothing here needs a badge to
-- be legible at the moment it matters.
--
-- One inherited edge, left standing rather than special-cased: Trait.flag is gagged by Sundered, so a
-- sundered corpse can be mended for as long as the break holds. That is the flag contract applied
-- evenly -- a bearer whose standing rules have gone quiet does not get to keep the quiet ones working --
-- and as a play it costs a whole cast to buy one heal on a body that rots on a timer anyway.
return {
    name = "Grave-Cold",
    description = "Mending does not reach the dead: every heal aimed at this body wounds it instead.",
    invertsHealing = true,
}
