-- GHOUL-NAIL PASTE: the Ghoul's. What is under the nails, scraped into a jar: coat the weapons beside it
-- and their next hits each Stun -- a small shove down the turn order. The claw's paralysis as a coating,
-- so it rides any weapon family without bending that family's contract. Three hits, one per charge.
return {
    name = "Ghoul-Nail Paste",
    description = "Coats adjacent weapons: their hits inflict a small Stun.",
    flavor = "Keep the lid on. Keep your own nails out of it. Keep, ideally, a second pair of gloves.",
    sprite = "assets/items/consumable_ghoul_nail_paste.png",
    type = "consumable",
    tags = { "coating" },
    class = "poisoner",
    unlockLevel = 5,
    unstocked = true,
    maxStack = 3,
    aura = {
        appliesTo = { "weapon" },
        status = { id = "status_stun", opts = { magnitude = 3 } },
    },
}
