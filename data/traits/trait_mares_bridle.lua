-- THE MARE'S BRIDLE: the assassin's drop off the Mare ("Sloth's Bestiary", 2026-10-04, approved word for word:
-- "Your blows do not wake a sleeping foe"). A flag, read by Combat.sparesSleep when the bearer's blow lands, so
-- Sleep's own onDamaged holds. Asleep is the status named Sleep; the foundation's Dormant is its own word and wakes
-- as it always did.
return {
    name = "The Mare's Bridle",
    description = "Your blows do not wake a sleeping foe.",
    sparesSleepers = true,
    notAReaction = true,
}
