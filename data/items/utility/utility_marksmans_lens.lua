-- The payoff the mark was always for (docs/classes.md, gluttony: setup then payoff). It grants the
-- Marksman's Lens trait (data/traits/trait_marksmans_lens.lua): the bearer's RANGED attacks hit a
-- Marked foe harder. The whole shelf spends its turns applying marks -- Mark Target, the Executioner's
-- Eye, the Scent Marker, the Falconer's hawk -- and this is the item that finally cashes them, from the
-- range a hunter was always meant to be shooting at.
--
-- Ranged-gated on purpose: a hunter decides the kill before the shot (docs/story.md, "The Hunter's
-- Lodge"). No stats of its own -- the cost is the slot, the beast-shelf's family price -- and it is
-- dead weight in a fight where the party lands no marks, which makes it a wager on your own setup.
return {
    name = "Marksman's Lens",
    description = "Ranged attacks deal extra damage against a Marked foe.",
    flavor = "The Lodge grinds them from river-glass. A mark is only a suggestion until you look through one of these.",
    sprite = "assets/items/marksmans_lens.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    unlockQuests = 3,
    dropTier = 5,
    traits = { "trait_marksmans_lens" },
    -- IT IS A LENS, AND IT NOW HELPS YOU AIM. Its own flavour says "a mark is only a suggestion until
    -- you look through one of these", and until accuracy existed it granted no aim at all -- only
    -- conditional damage against a body already Marked. The Skill is unconditional where the trait is
    -- gated: looking through a lens helps whether or not somebody painted the target for you.
    --
    -- A PLAIN NUMBER, AND IT HAS TO BE. Accuracy stats sit on a 0-10 band (docs/accuracy.md) while
    -- Curve.ramp refuses any span under 10, so no legal ramping skill curve exists at any base -- it
    -- would have to run 2 to 12 and leave the band climbing. A shallow hand-written curve is the other
    -- way out and was tried first; tests/curve_spec.lua refused it, correctly, because an item whose
    -- only magnitude holds at eight of ten levels still charges the bench for all ten.
    --
    -- So accuracy gear does not forge. That is the honest shape rather than a limitation worked around:
    -- what the forge sells is more of a number, and these numbers have nowhere to go.
    bonus = { skill = 3 },
}
