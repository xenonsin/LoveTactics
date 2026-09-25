-- SIREN SONG: what a Siren sings (data/characters/character_siren.lua), and the Lorelei after her. It
-- puts her into Singing (data/status/status_singing.lua), which fills everyone who hears her with Longing
-- and keeps doing it every turn until something hits her.
--
-- A creature's own voice and never loot: the company's version of the song was sent back twice on
-- review and became Echo instead (data/traits/trait_echo.lua), which borrows somebody else's words.
return {
    name = "Siren Song",
    description = "Sing: every foe within 4 tiles, or Wet anywhere, is filled with Longing each turn. Breaks when you are hit.",
    flavor = "Every sailor who ever heard it swears it was a song about him.",
    sprite = "assets/items/ability_siren_song.png",
    type = "ability",
    class = "creature",
    tags = { "magical" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        support = true,
        speed = 3,
        cost = { stat = "mana", amount = 6 },
        effect = function(fx)
            fx.applyStatus(fx.user, "status_singing")
        end,
    },
}
