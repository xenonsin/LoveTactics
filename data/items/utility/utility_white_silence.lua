-- WHITE SILENCE: the Yuki-onna's breath, lifted off her for an elementalist ("Sloth's Bestiary", 2026-10-04,
-- approved word for word). Her own rule, Snow-Sleep (trait_snow_sleep), turned on whoever stands still near the
-- bearer: a foe within 3 that ends its turn without moving gains Drowsy, and three Drowsy put it to Sleep by the
-- foundation's own rule. It answers the archer and the caster who plant their feet. An unstocked trophy on the
-- approach's rung.
return {
    name = "White Silence",
    description = "Foes within 3 that end a turn without moving gain Drowsy. At 3 Drowsy they fall Asleep.",
    flavor = "Snow does not make a sound. It waits for you to stop making yours.",
    sprite = "assets/items/utility_white_silence.png",
    type = "utility",
    tags = { "charm", "ice" },
    class = "elementalist",
    unlockLevel = 9,
    unstocked = true,
    traits = { "trait_snow_sleep" },
}
