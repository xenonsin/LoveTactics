-- THE SIRE'S SIGNET: the Sire's drop (Wrath's vampires, round 1). Blood Bond, worn by a company: while you stand,
-- no ally can be Charmed, Seeing Red or in Bloodlust; when you fall, every ally is in Bloodlust for two turns --
-- more damage, and the game takes their turns to bite whoever is nearest (trait_sires_signet, Status.allyWard).
return {
    name = "Sire's Signet",
    description = "While you stand, allies can't be Charmed, Seeing Red or in Bloodlust. When you fall, all allies Bloodlust for 2 turns.",
    flavor = "A heavy gold ring with a garnet seal, pressed into a hundred throats before yours.",
    sprite = "assets/items/utility_sires_signet.png",
    type = "utility",
    tags = { "trinket" },
    class = "warlord",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_sires_signet" },
}
