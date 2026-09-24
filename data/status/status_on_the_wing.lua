-- ON THE WING: the Griffin in the air, and Slay the Spire's Byrd by way of review (2026-09-23). Every
-- blow that reaches it is halved (Status.damageTakenScale), and every blow strips a stack; the last one
-- brings it down (data/traits/trait_on_the_wing.lua). So a flurry of light hits grounds it sooner than one
-- great swing -- the counterplay the review approved.
return {
    name = "On the Wing",
    abbr = "Wng",
    description = "Flying: takes half damage. Each blow strips a stack, and the last brings it down.",
    color = { 0.560, 0.700, 0.820 }, -- badge tint (sky)
    duration = 999,
    hideDuration = true,
    magnitude = 3,
    stacks = 3,
    damageTakenScale = 0.5,
}
