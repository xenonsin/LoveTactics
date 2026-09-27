-- THE COMMUNION CHALICE: the Communicant's drop (Wrath's vampires, round 1). At the end of your turn you lose 5% of
-- your max health and each adjacent ally heals that much. It counts as FEEDING, so it heals an undead ally rather
-- than wounding it -- a raised zombie, a vampire -- the one heal a company holds that Grave-Cold lets through
-- (trait_communion_chalice).
return {
    name = "Communion Chalice",
    description = "At the end of your turn, lose 5% of your max health; each adjacent ally heals that much, even the undead.",
    flavor = "A black-iron cup with a rim worn thin by many mouths.",
    sprite = "assets/items/utility_communion_chalice.png",
    type = "utility",
    tags = { "trinket" },
    class = "priest",
    unlockLevel = 8,
    unstocked = true,
    traits = { "trait_communion_chalice" },
}
