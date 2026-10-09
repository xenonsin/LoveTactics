-- CROWN OF THORNS: an inquisitor's trophy off the Hollow Crown (slice D). A passive area, as the author asked: every
-- ability a foe uses within 2 of the bearer costs it a tenth of its max health (trait_crown_of_thorns). On the
-- inquisitor's rack because the house's whole trade is making a working cost the one who works it.
return {
    name = "Crown of Thorns",
    description = "Foes within 2 of you lose a tenth of their max health each time they use an ability.",
    flavor = "Somebody has to wear the one that hurts.",
    sprite = "assets/items/utility_crown_of_thorns.png",
    type = "utility",
    tags = { "charm" },
    class = "inquisitor",
    unlockLevel = 15,
    unstocked = true,
    traits = { "trait_crown_of_thorns" },
}
