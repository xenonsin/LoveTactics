-- The Priest's innate: they walk on consecrated ground. Each tick, every ally standing orthogonally
-- adjacent -- and the Priest themselves -- mends a little health (Combat.SANCTIFY_HEAL). A slow,
-- positional font of life that rewards keeping the company close, and asks nothing to cast.
--
-- Like Overchannel, this is a capability the recovery loop reads (Combat.regenerate checks
-- Trait.has "trait_sanctified_presence" on nearby allies) rather than a dispatched hook, so the def carries
-- no hook -- it exists to be attached and detected.
return {
    name = "Sanctified Presence",
    description = "Allies adjacent to you (and you) mend a little health each tick.",
}
