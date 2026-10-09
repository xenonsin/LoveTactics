-- COMMAND: the Archon Duke's own, in both its bodies (character_archon_duke, character_archon_duke_ascended; "The
-- Crown's Bestiary", slice A, 2026-10-09). It carries Command (trait_ducal_command): Archons within 3 of the Duke act
-- before the company's bodies do.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player.
return {
    name = "Command",
    description = "At the end of its turn, Archons within 3 of it move ahead of every foe in the turn order.",
    flavor = "The court moves when the Duke has finished speaking, and not one breath after.",
    sprite = "assets/items/utility_ducal_command.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_ducal_command" },
}
