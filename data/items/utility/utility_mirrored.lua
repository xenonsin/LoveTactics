-- MIRRORED: the Mirror-Knight's organ (data/characters/character_mirror_knight.lua). Reviewed 2026-10-01..03
-- ("Envy's Bestiary", approved in round 2). It starts each of its turns wearing Reflect Steel and Reflect Magic; the
-- first single-target attack on it in a round rebounds, and then the mirror is down until its next turn
-- (trait_mirrored). Bound and unstealable, so it rides into every face the knight puts on.
return {
    name = "Mirrored",
    description = "At the start of your turn, gain Reflect Steel and Reflect Magic. The first blow they turn ends both.",
    flavor = "Its shield shows you yourself. Nobody has ever liked what they saw in time to stop swinging.",
    sprite = "assets/items/utility_mirrored.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_mirrored" },
}
