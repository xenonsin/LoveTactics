-- THE SURFEIT HEART: the Gorged's drop (Wrath's vampires, approved 2026-09-26/27). What it could not hold, worn by
-- somebody who can: healing past full is kept as a shield, up to a quarter of max health, and it stays until the
-- next hit lands (trait_surfeit_heart). A priest's piece, because a priest is what pours the heal that overflows.
return {
    name = "Surfeit Heart",
    description = "Healing past max health becomes a shield, up to 25% of your max. The shield breaks when you're hit.",
    flavor = "Dark, heavy and still warm, though nobody can say how long it has been out of the body.",
    sprite = "assets/items/utility_surfeit_heart.png",
    type = "utility",
    tags = { "trinket" },
    class = "priest",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_surfeit_heart" },
}
