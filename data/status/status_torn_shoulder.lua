-- Torn Shoulder: the Damage half of data/injuries/injury_torn_shoulder.lua.
--
-- IT REPLACES `status_wounded`, which was the count-based meter's one badge -- a damage cut whose
-- magnitude scaled with how many times you had been carried out. That blueprint is deleted: the ladder
-- it scaled on does not exist any more, and a body's damage cut now comes from a named thing that
-- happened to a shoulder rather than from a tally.
--
-- WHAT IT KEEPS from that blueprint is the reason it is a status at all: an injury has to be READABLE.
-- The player needs to see, on the timeline strip and in the damage breakdown, that this body is swinging
-- short because of something that happened two floors ago. A quiet subtraction from `damage` is a number
-- nobody can account for.
--
-- A negative `statBonus` is unusual in this catalogue and entirely intentional -- Given Guard does the
-- same and Status.statBonus simply sums it -- so the shortfall shows as its own signed row under its own
-- name. See data/status/status_shattered_leg.lua for why `debuff = false`.
return {
    name = "Torn Shoulder",
    abbr = "Shld",
    description = "Torn Shoulder: strikes for less.",
    color = { 0.639, 0.612, 0.451 }, -- badge tint (wrung-out olive)
    duration = 9999,
    debuff = false,
    statBonus = { damage = -3 },
}
