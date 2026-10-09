-- HOLD THE GATE: the Archon Warden's own (data/characters/character_archon_warden.lua; "The Crown's Bestiary", slice
-- A, 2026-10-09). It carries the post (trait_hold_the_gate, `court = true`): on any turn the Warden has not moved,
-- every Archon within 2 of it takes half from anything struck from farther than 2 tiles.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Warden's Post, the same rule over every ally).
return {
    name = "Hold the Gate",
    description = "On a turn it did not move, Archons within 2 take half damage from foes farther than 2 tiles.",
    flavor = "Somebody has to stand in the door between the spheres. It was asked once, and has not moved since.",
    sprite = "assets/items/utility_hold_the_gate.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_hold_the_gate" },
    traitParams = { court = true },
}
