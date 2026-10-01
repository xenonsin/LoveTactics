-- PHOENIX FEATHER: what the Phoenix drops (data/characters/character_phoenix.lua; "Pride's Bestiary",
-- 2026-09-30). Once a battle, a killing blow does not keep the bearer down: it rises at 30% of its health.
--
-- SECOND WIND TOLD ANOTHER NUMBER, deliberately: the rule "refuse one death and stand back up at a share of the
-- bar" is already trait_second_wind, read through Trait.trySurvive, and a second trait for the same refusal at a
-- different share is the duplicate Trait.param exists to stop (the Empty Chair rises at a sliver off the same
-- file). Not Bone-Knit either: that one is paid in mana, as often as the pool allows, and rises whole. This is
-- free, once, and thin -- the Phoenix's own return, without the three turns of ash.
--
-- A Priest's, because standing somebody back up is the Priest's shelf. An unstocked trophy on the seat's rung.
return {
    name = "Phoenix Feather",
    description = "Once per battle, when you fall, rise at 30% health.",
    flavor = "It is still warm. It has been warm for as long as anybody has owned it.",
    sprite = "assets/items/utility_phoenix_feather.png",
    type = "utility",
    tags = { "charm" },
    class = "priest",
    unlockLevel = 14,
    unstocked = true,
    traits = { "trait_second_wind" },
    traitParams = { revivesAt = 0.3, revivesLine = "%s rises from the ash!" },
}
