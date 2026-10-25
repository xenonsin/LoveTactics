-- FOG: no aim crosses more than three tiles, for either side. The Long Shadow's horizon
-- (`longShadow`, Status.concealedAt and Combat.abilityRange) worn by every body on the board, so the
-- player's targeting, the target list and the AI's stand-tile search all read the same cap.
return {
    name = "Fog",
    description = "Nothing can be aimed at from more than 3 tiles away.",
    color = { 0.70, 0.74, 0.80 },
    rules = { longShadow = 3 },
}
