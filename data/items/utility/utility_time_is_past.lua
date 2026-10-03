-- TIME IS PAST: one of the Brazen Head's two drops (data/characters/character_brazen_head.lua; "Envy's Bestiary",
-- 2026-10-03, slice C, round 2's option B). The head's last word, kept for whoever carries it: when you fall, every
-- foe within 3 is Stunned (trait_time_is_past).
--
-- An Artificer's: the head is a made thing, and a made thing that goes off when it breaks is that shelf's. An
-- unstocked trophy on the seat's rung.
return {
    name = "Time Is Past",
    description = "When you fall, every foe within 3 is Stunned.",
    flavor = "It was always going to say this last. It only needed somebody to stop listening.",
    sprite = "assets/items/utility_time_is_past.png",
    type = "utility",
    tags = { "charm" },
    class = "artificer",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_time_is_past" },
}
