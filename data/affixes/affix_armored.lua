-- ARMORED: the body walks in behind a barrier, and the first blows only break it.
-- Reuses the Physical Barrier a spell grants (data/status/status_physical_barrier.lua): `magnitude` is how
-- many physical blows it swallows. Long enough that it is still up when the company reaches it.
return {
    name = "Armored",
    description = "Opens behind a barrier that stops the first two physical blows.",
    mark = "A",
    color = { 0.70, 0.77, 0.88 },
    statuses = { { id = "status_physical_barrier", magnitude = 2, duration = 60 } },
}
