-- THE CLAN STANDS: the Oni General's third verb (utility_the_clan_stands). Approved 2026-09-27 ("The Oni of
-- Wrath", round 2, as "the Clan's Last Stand"; renamed here because Last Stand is already a trait in this game).
--
-- While the General stands, an oni of its side that takes a lethal blow stays up at 1 health under Not Yet for
-- one more action, once a body. The whole rule is read by Trait.trySurvive off this flag; kill the General and
-- the clan falls when it is struck down.
return {
    name = "The Clan Stands",
    description = "While you stand, an oni of your side that would fall stays up at 1 health for one more action, once.",
    clanStands = true,
    notAReaction = true,
}
