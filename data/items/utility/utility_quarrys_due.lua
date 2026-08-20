-- Quarry's Due: the hunter half of the Poacher (rogue x hunter). Anything caught in a trap you set is
-- Marked.
--
-- It authors no trap, and that is the point. The first draft of this slot was a Wire Snare -- a hidden
-- trap that Rooted and Marked -- and the shelf already had two of those (ability_snare_stake and
-- consumable_snare_stake_kit, both Trapper). What the Poacher was missing was never another thing to
-- put on the ground; it was a reason for the ground and the knife to be the same build.
--
-- So this is a clause, and it attaches to every trap in the game: a Bear Trap, a Snare Stake, a
-- Blightstake, a Caltrop trail, and anything anyone authors later. Mark cuts defense and magic defense,
-- which is what makes Throatcut land -- and it now also stops the victim vanishing (status_mark's
-- `forbids`), so a rogue cannot slip a poacher's snare by turning Invisible in it.
--
-- Keyed to the trapper, not the side: two hunters in one line do not share each other's charms.
return {
    name = "Quarry's Due",
    description = "Anything caught in a trap you set is Marked.",
    flavor = "Setting the snare is the easy half. The paperwork is knowing which one is yours.",
    sprite = "assets/items/utility_quarrys_due.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    discipline = "poacher",
    price = 475,
    unlockQuests = 3,
    traits = { "trait_quarrys_due" },
}
