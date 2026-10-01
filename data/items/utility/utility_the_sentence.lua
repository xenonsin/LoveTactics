-- THE SENTENCE: the Throne's organ for its second phase (reviewed 2026-09-30, "Pride's Bestiary"). Every third
-- turn it chains two of the company together (trait_the_sentence, status_sentenced).
--
-- Bound and unstealable: an organ, never kit.
return {
    name = "The Sentence",
    description = "Every third turn, chains the two foes furthest apart. Ending a turn more than 2 apart hurts both.",
    flavor = "It does not choose the two who deserve it. It chooses the two who least want to be near each other.",
    sprite = "assets/items/utility_the_sentence.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_sentence" },
}
