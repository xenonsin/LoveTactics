-- Coveted Blood: a stoppered thing the alchemist wears open. It lays a cloud around its bearer that
-- travels with them (data/hazards/hazard_exposure.lua), and every foe standing in it takes extra
-- damage from PIERCING hits -- from everyone. Not from the alchemist. From everyone.
--
-- This is the purest statement the Crucible has of what its sin actually is. The item deals no damage,
-- lands no status the bearer benefits from, and cannot kill anything at any level of the forge. Its
-- damage stat is the rest of your party -- the archer's shot, the spear's line, the dagger you were
-- going to open with anyway -- exactly as the Vitriol Wand's is (docs/weapons.md). Envy does not want
-- to be the one who kills. It wants the kill to have needed it.
--
-- A DELIBERATE BORROW, said out loud as docs/classes.md asks. `incense` is the censer family's
-- mechanism -- ground that WALKS, as against a banner's ground that stays and a trail's ground you
-- leave behind (docs/weapons.md, "Incense") -- and the censer family belongs to the Cathedral and no
-- one else. What is borrowed here is the machine and not the object: this is not a censer, carries no
-- censer tag, swings at nobody and cannot be swung. What the Crucible wanted was the one existing way
-- to say "a zone that is wherever I am", and writing a second one would have been two machines for one
-- idea. The taboo the Cathedral keeps is about EDGES, and there is no edge on this.
--
-- Why a walking cloud rather than a thrown one: because a thrown zone is a bomb, and the shelf has
-- four of those. Making the alchemist carry it puts the frailest body in the party inside the enemy's
-- reach for as long as the effect is wanted, which is the price that makes the effect worth having.
-- Where it is standing IS the decision -- and that is a positional item on a shelf that had none.
--
-- `radius` deliberately does not scale with the forge, on the same principle the Hallowed Censer
-- follows: an upgrade buys a stronger blessing, never a wider one (see Combat.layIncense).
return {
    name = "Coveted Blood",
    description = "Lays a cloud around you: foes standing in it take extra damage from piercing hits.",
    flavor = "It is not that she wants them dead. It is that she wants to have been necessary.",
    sprite = "assets/items/utility_coveted_blood.png",
    type = "utility",
    tags = { "charm", "poison" },
    class = "alchemist",
    discipline = "apothecary", -- priest + alchemist; the Lent-vitality mechanic's first stock
    price = 460,
    repRank = 3,
    -- The cloud: laid around the bearer on every move and re-laid from Combat.rebase for one that
    -- never moves, lifted by owner+id before each re-lay so it walks rather than piling into a wake.
    incense = { hazard = "hazard_exposure", radius = 1, amount = { 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13 } },
}
