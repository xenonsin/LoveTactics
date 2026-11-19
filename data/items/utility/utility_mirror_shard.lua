-- Mirror Shard: the Ninja's grid joker (docs/engines.md). It carries a second copy of every trait on the
-- item to its RIGHT in the same row (Trait.attach): a second parry, a second thorn, a second tally. Put it
-- at the right edge, or beside an item with no traits, and it carries nothing.
--
-- On the Ninja because the Ninja already leaves a clone standing where it was: copying is its thing. A
-- new item beside the Ninth Sigil, which keeps its workings (the author's "keep both", round 2).
return {
    name = "Mirror Shard",
    description = "Copies the traits of the item to its right.",
    flavor = "A sliver of a mirror the Undercroft will not say where it found.",
    sprite = "assets/items/utility_mirror_shard.png",
    type = "utility",
    tags = { "charm" },
    class = "ninja",
    unlockLevel = 7,
    mirrorsRight = true,
    bonus = { luck = 1 },
}
