-- FLAWLESS FORM: Superbia's perfection (reviewed over three rounds, "Pride's Generals"). No single blow takes more
-- than a tenth of her max health (trait_flawless_form), so she is never burst: ten blows at the least.
--
-- Bound and unstealable: an organ, never kit. Perfect Plate carries the rule at a quarter for a knight.
return {
    name = "Flawless Form",
    description = "No single blow can take more than a tenth of your max health.",
    flavor = "There is no angle she looks worse from. She has checked every one.",
    sprite = "assets/items/utility_flawless_form.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_flawless_form" },
}
