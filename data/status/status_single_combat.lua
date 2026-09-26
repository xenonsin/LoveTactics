-- SINGLE COMBAT: the Pit-Fighter's Belt (data/traits/trait_pit_fighters_belt.lua) -- the Challenge turned round.
-- The bearer takes half damage from every foe except the one it last struck (the instance's `exempt`,
-- Status.damageTakenScale).
return {
    name = "Single Combat",
    abbr = "Sngl",
    description = "Take half damage from every foe except the one you last struck.",
    color = { 0.720, 0.560, 0.200 },
    duration = math.huge,
    hideDuration = true,
    damageTakenScaleExcept = 0.5,
}
