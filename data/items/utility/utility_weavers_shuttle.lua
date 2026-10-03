-- WEAVER'S SHUTTLE: what Arachne drops (data/characters/character_arachne.lua; "Envy's Bestiary", 2026-10-03, slice
-- C). When a foe casts the same ability a second time, you may cast it once: the bearer is lent a copy of it
-- (trait_weavers_shuttle, Combat.lendItem), recalled when it is used.
--
-- A Theurge's, as the page wrote it. An unstocked trophy on the seat's rung.
return {
    name = "Weaver's Shuttle",
    description = "When a foe casts the same ability a second time, you may cast it once.",
    flavor = "Pass it through once and you have a thread. Pass it through twice and you have a pattern.",
    sprite = "assets/items/utility_weavers_shuttle.png",
    type = "utility",
    tags = { "charm" },
    class = "theurge",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_weavers_shuttle" },
}
