-- HELD NOTE: one of the Lorelei's own (data/characters/character_lorelei.lua), and her rock handed
-- over. The first thing each battle that would break the bearer's sustained cast -- a channel
-- interrupted by a stun, a shove or a sleep, a song struck -- does not (trait_held_note, read by
-- Combat.holdsTheNote). What makes a channel survive the round it matters.
--
-- `unstocked`: visible on the Cathedral's rack and never sold (docs/drops.md).
return {
    name = "Held Note",
    description = "The first time each battle your channel would be interrupted, it is not.",
    flavor = "The last sailor to hear it said the note never ended. He was the last one for a reason.",
    sprite = "assets/items/utility_held_note.png",
    type = "utility",
    tags = { "arcane" },
    class = "priest",
    unlockLevel = 4,
    unstocked = true,
    traits = { "trait_held_note" },
}
