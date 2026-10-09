-- WARDEN'S POST: the Archon Warden's trophy (data/characters/character_archon_warden.lua; "The Crown's Bestiary",
-- slice A, 2026-10-09). The body's own rule turned on the bearer's line: on a turn the bearer did not move, every ally
-- within 2 takes half from foes farther than 2 tiles (trait_hold_the_gate, every ally rather than the court). A
-- Sentinel's, because standing still so the line behind you lives is what that house is.
return {
    name = "Warden's Post",
    description = "On a turn you didn't move, allies within 2 take half damage from foes farther than 2 tiles.",
    flavor = "The door was never the wall. The door was whoever would not get out of it.",
    sprite = "assets/items/utility_wardens_post.png",
    type = "utility",
    tags = { "charm" },
    class = "sentinel",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_hold_the_gate" },
}
