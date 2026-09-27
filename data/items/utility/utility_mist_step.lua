-- MIST STEP: the Vampire Duelist's organ (trait_mist_step). The first blow each round turns it to mist; it re-forms
-- 2 tiles away and the attacker Bleeds. Its drop is the same trick without the pick, the Mistcloak.
return {
    name = "Mist Step",
    description = "The first blow you take each round does no damage: you turn to mist, re-form 2 tiles away, and the attacker Bleeds.",
    flavor = "The blade goes through grey vapour, and the vapour is standing two paces to the left.",
    sprite = "assets/items/utility_mist_step.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_mist_step" },
}
