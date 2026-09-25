-- HORN CALL: the Hornblower's horn (data/items/ability/ability_sound_the_horn.lua) -- one more tile of
-- movement, for about a turn.
return {
    name = "Horn Call",
    abbr = "Horn",
    description = "The horn has sounded: increase movement.",
    color = { 0.600, 0.470, 0.300 }, -- badge tint (old bronze, as the banner)
    duration = 6, -- ~one turn at Status.TICKS_PER_TURN
    statBonus = { movement = 1 },
}
