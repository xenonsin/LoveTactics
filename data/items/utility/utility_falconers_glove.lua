-- The Falconer's Glove: a hawk on the wrist, and it marries the two verbs gluttony's shelf is built on
-- -- beasts and the mark (docs/classes.md). It grants the Falconer's Hawk trait
-- (data/traits/trait_falconers_hawk.lua): a hawk fields at the bearer's side at the opening bell and
-- Marks the nearest foe, free of a turn or a cast.
--
-- Distinct from the Companion Whistle on the same shelf, which fields a WOLF -- a body that fights. The
-- hawk is a spotter: fragile, soft-hitting, and worth carrying entirely for that first free mark, which
-- the Marksman's Lens then shoots harder and the whole party follows up into. Setup handed to you before
-- anyone has moved, which is the shelf's own thesis in a single charm.
--
-- No stats of its own beyond the bird -- the cost is the slot. One hawk, granted once: it cannot be
-- resummoned, and it falls if the bearer does (the trait sustains it, like the Archer's wolf).
return {
    name = "Falconer's Glove",
    description = "A hawk starts at your side and Marks the nearest foe at the opening bell.",
    flavor = "The Lodge trains the bird, not the hunter. The bird already knows which one is going to die.",
    sprite = "assets/items/falconers_glove.png",
    type = "utility",
    tags = { "beast" },
    class = "hunter",
    price = 340,
    repRank = 3,
    traits = { "trait_falconers_hawk" },
}
