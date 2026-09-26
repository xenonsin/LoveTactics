-- THE WIGHT'S BODY: half in the world. It drifts through rock and through bodies alike (`flying` opens
-- the ground, `moveBehavior` phase opens a line -- the two existing seams, together), and a weapon blow
-- goes through the half that is not there (trait_half_here). Bound and noSteal: an organ, not kit.
return {
    name = "Barrow-Shade",
    description = "Drifts through rock and bodies. Weapon blows have half the chance to hit it, unless it is lit.",
    flavor = "It does not walk down the passage. It is simply further down it than it was.",
    sprite = "assets/items/utility_wight_body.png",
    type = "utility",
    class = "creature",
    tags = { "flying", "dark" },
    noSteal = true,
    bound = true,
    moveBehavior = { mode = "phase" },
    traits = { "trait_half_here" },
}
