-- BLOODHOUND'S SCENT: the Fledgling's second drop (Wrath's vampires, round 2). The vampire's Scent of Blood for a
-- living hunter: +2 movement on a move that ends next to a bleeding foe, and +20% damage to bleeding foes
-- (trait_bloodhounds_scent). Pairs with anything that opens a wound: a dagger, a Familiar.
return {
    name = "Bloodhound's Scent",
    description = "Move 2 further when the move ends next to a bleeding foe. Deal 20% more damage to bleeding foes.",
    flavor = "A pouch of dried blood-moss worn at the throat, sharp enough to smell a cut across the field.",
    sprite = "assets/items/utility_bloodhounds_scent.png",
    type = "utility",
    tags = { "trinket" },
    class = "hunter",
    unlockLevel = 7,
    unstocked = true,
    traits = { "trait_bloodhounds_scent" },
}
