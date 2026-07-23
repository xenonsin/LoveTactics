-- The Slipchain Charm: a rogue does not get pinned. Where the Deadhand Grip (its sibling on this shelf)
-- refuses Disarmed, this refuses the two statuses that take a rogue's legs -- Rooted and Mired -- and a
-- rogue with no legs is a rogue with no kit, since guile is "conditional multipliers, return-to-origin
-- blinks, and taking what is not yours" (docs/classes.md) and every one of those is a thing you do by
-- MOVING. Net, snare, mire and grasping ground are how the slow things in this game answer the fast
-- ones; this is greed buying its way out of that answer.
--
-- The trade is the grid slot, the whole cost of this family (compare the Deadhand Grip, the Tempered
-- Gut, the Untroubled Mind): no stats, and it does nothing in a fight where nobody tries to hold you.
-- Carrying one is a read on the encounter, not a build -- which is the point, because a blanket defence
-- is what the resistance curve already sells, at a curve's price.
return {
    name = "Slipchain Charm",
    description = "The bearer cannot be pinned: immune to Rooted and Mired.",
    flavor = "The Undercroft's first rule is to never be where the blow lands. Its second is to never be held there.",
    sprite = "assets/items/slipchain_charm.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 280,
    repRank = 2,
    statusImmunity = { "status_root", "status_mired" },
}
