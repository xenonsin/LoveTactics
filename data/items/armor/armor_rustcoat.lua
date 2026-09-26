-- RUSTCOAT: the Rust Mite's hide, made for a person. Any weapon that strikes you in melee rusts
-- (trait_rust_hide, status_tarnished): 2 less damage with that weapon for the fight, stacking to -6.
-- Reviewed 2026-09-25 ("The Coin-Eaters"), replacing a buff-thief the review judged not worth a slot.
--
-- A TANK'S COAT. The body that is struck most is the body this pays most on: every melee enemy that
-- keeps swinging at it gets worse at it, fight-long, and the rust is on the WEAPON -- so it pays against
-- the one that keeps coming. Knight stock beside the Bog-Hopper Greaves, which it was pitched to pair
-- with. Rift-only: a trophy off the mite. Every armour costs a square of pace.
local Curve = require("models.curve")

return {
    name = "Rustcoat",
    description = "Any weapon that strikes you in melee is Tarnished.",
    flavor = "It was a good coat of mail once. Now it is a good reason not to hit you with a sword.",
    sprite = "assets/items/armor_rustcoat.png",
    type = "armor",
    tags = { "mail" },
    class = "knight",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_rust_hide" },
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
}
