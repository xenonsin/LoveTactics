-- Reactive Salts: the Bombardier's compound of the alchemist's Reactions (docs/engines.md). Every bomb the
-- bearer throws leaves its blast as reaction ground (trait_reactive_blasts): ice Chills, lightning
-- soaks, acid and oil slick. The bombardier's blasts become the setup for the party's payoffs.
return {
    name = "Reactive Salts",
    description = "Your bombs leave reaction ground: ice leaves Chilled, lightning leaves Wet, acid and oil leave Oiled.",
    flavor = "A pinch in every casing. The Crucible charges more for the pinch than for the casing.",
    sprite = "assets/items/utility_reactive_salts.png",
    type = "utility",
    tags = { "charm" },
    class = "bombardier",
    unlockLevel = 5,
    traits = { "trait_reactive_blasts" },
    bonus = { skill = 1 },
}
