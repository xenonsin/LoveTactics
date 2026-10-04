-- SNOW-SLEEP: the Yuki-onna's organ (data/characters/character_yuki_onna.lua), carrying her rule (trait_snow_sleep).
-- Creature kit: bound, unstealable, on no shelf. What a company takes off her instead is White Silence.
return {
    name = "Snow-Sleep",
    description = "Foes within 3 that end a turn without moving gain Drowsy. At 3 Drowsy they fall Asleep.",
    flavor = "She does not chase anybody. She waits for them to stop, and everybody stops.",
    sprite = "assets/items/utility_snow_sleep.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_snow_sleep" },
}
