-- BLOOD BOND: the Sire's organ (trait_blood_bond) -- the bond that holds its brood out of Bloodlust while it stands,
-- the tithe of every drink they take, and the leash that snaps when it falls.
return {
    name = "Blood Bond",
    description = "While you stand, your vampires can't Bloodlust; when you fall, they all do. Heal 10% of every drink they take.",
    flavor = "A thread of its own blood runs in every one of its brood, and it can feel each one pull.",
    sprite = "assets/items/utility_blood_bond.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_blood_bond" },
}
