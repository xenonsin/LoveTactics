-- The item that carries Follow-Up (data/traits/trait_follow_up.lua): when an ally lands a blow on a foe
-- standing next to the wearer, the wearer piles on with a swing of its own.
--
-- A passive utility whose whole effect is the trait it grants, like the Duelist's Reflex beside it on
-- the shelf. Sold by the fighter's vendor -- wrath's line, and a pincer is wrath at its most collective:
-- the reward for two of you catching one of them between you (see docs/story.md).
--
-- It wants a FORMATION, not a duel: the payout needs an ally landing the opening blow and a foe pinned
-- adjacent to you when they do, so it turns a shoulder-to-shoulder line into a threat that punishes every
-- body that steps into the middle of it. The follow-up costs a swing's stamina, doubled per answer
-- already thrown this round (Trait.answerCost), so pressing every opening on a crowded flank drains the
-- wearer fast rather than being free.
return {
    name = "Pincer Banner",
    description = "When an ally strikes a foe beside you, you strike it too (a swing's stamina, escalating).",
    flavor = "The old drill-line's whole cruelty in one word: never let them face just one of you.",
    sprite = "assets/items/pincer_banner.png",
    type = "utility",
    tags = { "banner" },
    class = "fighter",
    discipline = "warlord", -- a banner is a Paladin or Warlord object (docs/classes.md), whatever it delivers
    price = 345,
    unlockQuests = 2,
    traits = { "trait_follow_up" },
}
