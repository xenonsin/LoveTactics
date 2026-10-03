-- ECHOING SHELL: what the Echo drops (data/characters/character_echo.lua; "Envy's Bestiary", 2026-10-03, slice C).
-- When a foe within 3 casts an ability, you become Idle: the next thing you use costs nothing (trait_echoing_shell).
--
-- The page said "your next spell costs nothing". Idle is the game's one word for a next use that costs nothing
-- (Idle Hands), and it waives the next use whatever it is, so the text says Idle rather than promise a spell-only
-- waiver the engine does not keep.
--
-- A Spellbreaker's, on the author's note "not mage, choose a different class": a foe's working turned into the
-- bearer's own is that shelf's. An unstocked trophy on the seat's rung.
return {
    name = "Echoing Shell",
    description = "When a foe within 3 casts an ability, you become Idle.",
    flavor = "Hold it to your ear and you hear the last thing said near it. Say something.",
    sprite = "assets/items/utility_echoing_shell.png",
    type = "utility",
    tags = { "charm" },
    class = "spellbreaker",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_echoing_shell" },
}
