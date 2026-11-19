-- THE CLAN STANDS: the Oni General's third verb (utility_the_clan_stands). Approved 2026-09-27 ("The Oni of
-- Wrath", round 2, as "the Clan's Last Stand"; renamed here because Last Stand is already a trait in this game).
--
-- While the General stands, an oni of its side WITHIN `radius` of it that takes a lethal blow stays up at 1 health
-- under Not Yet for one more action, once a body. The whole rule is read by Trait.trySurvive off this flag.
--
-- THE REACH IS NEW (2026-11-19, the creature identity pass). It covered the whole board, which made the General
-- the oni's kill-the-head alpha in the same shape as the Hobgoblin and the Warchief. Within 2 it is a POSITION
-- lever: the oni at its side do not fall, the ones drawn off it do, so the company fights the clan away from it.
return {
    name = "The Clan Stands",
    description = "While you stand, an oni of your side within 2 that would fall stays up at 1 health for one more action, once.",
    clanStands = true,
    radius = 2,
    notAReaction = true,
}
