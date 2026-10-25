-- SWIFT: two more tiles of movement for the whole fight, and it opens Hasted for its first turns
-- (data/status/status_hasted.lua).
return {
    name = "Swift",
    description = "Has +2 Move, and opens the fight Hasted.",
    color = { 0.88, 0.80, 0.47 },
    bonus = { movement = 2 },
    statuses = { { id = "status_hasted", duration = 10 } },
}
