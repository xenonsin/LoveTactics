-- THE HOST AND THE FALL: Superbia's two stages (reviewed over three rounds, "Pride's Generals"). At two-thirds
-- health the Host descends, two Reflections a turn; at one-third she falls, the Reflections shatter, and Black Ice
-- spreads a ring a turn from where she landed (trait_the_host_and_the_fall, models/morning_star.lua).
--
-- Bound and unstealable: an organ, never kit. The Mirror of the Morning carries the Host, once, for a summoner.
return {
    name = "The Host and the Fall",
    description = "At 2/3 health Reflections join her each turn. At 1/3 they shatter, she falls, and ice spreads.",
    flavor = "She fell exactly once. Everything under her has been frozen since.",
    sprite = "assets/items/utility_the_host_and_the_fall.png",
    type = "utility",
    tags = { "natural", "ice" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_host_and_the_fall" },
}
