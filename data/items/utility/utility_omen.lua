-- OMEN: a theurge's trophy off the Hollow Crown (slice D). The Crown shows every want a turn before it acts it; worn,
-- the lesson turns round, and every wind-up a foe begins quickens the bearer's whole line (trait_omen). Capped once
-- per foe each round, as the review flagged it might need to be against a body that does nothing but wind up.
return {
    name = "Omen",
    description = "Each time a foe winds up, every ally gains Haste for a turn. Once per foe each round.",
    flavor = "It always told you a turn ahead. It never thought you would listen.",
    sprite = "assets/items/utility_omen.png",
    type = "utility",
    tags = { "charm" },
    class = "theurge",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_omen" },
}
