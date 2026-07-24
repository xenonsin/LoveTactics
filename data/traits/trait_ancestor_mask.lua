-- Ancestor Mask: the standing rule of the Shaman's charm of the same name. Nothing the bearer summons
-- takes damage from ground -- fire, acid, quicksand, or anything authored later.
--
-- A flag (Trait.flag) read inside the hazard context's own `damage` closure, which is the single point
-- every zone in the game reaches for to hurt somebody. So the rule holds across all 24 hazards without
-- any of them knowing it exists.
--
-- Only the DAMAGE is waived, never the statuses: a spirit standing in a Gagging Storm is still Silenced,
-- one in quicksand is still Mired. "The weather does not burn its own" is a narrower claim than "the
-- weather does not touch its own", and the narrower one is the interesting item -- a shaman still has to
-- think about where the spirits stand, just not about whether the fire will eat them.
--
-- It is what makes the Shaman's two halves one build. Call Spirit and Bind Spirit put bodies on the
-- field; the hunter's shelf covers the ground in weather; and until this, the second was killing the
-- first.
return {
    name = "Ancestor Mask",
    summonsShrugHazards = true,
}
