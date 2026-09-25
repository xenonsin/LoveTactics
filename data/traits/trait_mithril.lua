-- Mithril: the Mithril Shirt's two rules (data/items/armor/armor_mithril_shirt.lua).
--
--   critProof        Combat.critChance answers 0 against the bearer, and the forced-critical check on the
--                    blow is refused the same way, so the forecast and the swing agree.
--   revivesOnLethal  Trait.trySurvive -- Second Wind's rule, once a fight (the latch on `stacks`), at a
--                    sliver: `revivesAt = 0` floors to 1 health. The troll's spear, and the shirt under
--                    the coat that it found instead.
return {
    name = "Mithril",
    description = "No blow against you is ever a critical. Once a fight, a killing blow leaves you at 1 health.",
    critProof = true,
    revivesOnLethal = true,
    revivesAt = 0,
    revivesLine = "The blow finds mithril under %s's coat.",
}
