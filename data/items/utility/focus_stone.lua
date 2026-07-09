-- A focus item: no active ability, but it swaps the holder's Wait action into Focus -- end the
-- turn without attacking, restoring mana, at a larger time cost than a plain wait. See
-- Combat.waitBehavior / Combat.focus.
return {
    name = "Focus Stone",
    description = "A meditative charm. Replaces Wait with Focus: skip your turn to recover mana.",
    sprite = "assets/items/focus_stone.png",
    type = "utility",
    -- A heavy time cost: meditating to recover mana means giving up a big slice of the timeline.
    waitBehavior = { kind = "focus", mana = 12, speed = 10 },
}
