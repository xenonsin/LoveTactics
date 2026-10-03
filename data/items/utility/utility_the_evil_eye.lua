-- THE EVIL EYE: the Evil Eye's own (data/characters/character_evil_eye.lua; "Envy's Bestiary", round 1). It
-- carries the look -- at the start of its turn it sours a blessing of the Fairest it can see into Rattled
-- (trait_the_eye_falls) -- and the float, which is the `flying` tag (Combat.isFlying).
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (the Nazar).
return {
    name = "The Evil Eye",
    description = "Floats. At the start of its turn, sours one blessing of the Fairest it can see into Rattled.",
    flavor = "It does not want what you have. It wants you not to have it, which is cheaper.",
    sprite = "assets/items/utility_the_evil_eye.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "flying" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_the_eye_falls" },
}
