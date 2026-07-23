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
    description = "Your ranged attacks deal extra damage against a Marked foe.",
    flavor = "The Lodge grinds them from river-glass. A mark is only a suggestion until you look through one of these.",
    sprite = "assets/items/marksmans_lens.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    price = 300,
    repRank = 3,
    traits = { "trait_marksmans_lens" },
}
