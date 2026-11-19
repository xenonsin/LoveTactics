-- BARE BONES: what is left of a body when everything that could rot has.
--
-- The companion piece to data/items/utility/utility_grave_cold.lua, and the two are deliberately not one
-- file. Grave-Cold is what being DEAD does (a heal wounds it), and every raised thing in the game has it,
-- flesh or not -- the zombie included. This is what being a SKELETON does, which is a narrower claim
-- about one kind of corpse: there is nothing left on the frame to bleed, and it does not look like the
-- person any more.
--
-- IT IS ALSO WHERE THE PICTURE LIVES, and that is most of why it exists. `wearerSkin` makes the bearer
-- draw from its own token's bone variant (Character.spriteOf; tools/char_compose.lua writes one beside
-- every token), so a Skeleton Knight is the KNIGHT's silhouette in bone and a Skeleton Archer is the
-- archer's. Folding this into Grave-Cold would have drawn the zombie as a skeleton too, which is the one
-- body in the folder that is emphatically still wearing its skin.
--
-- Unpriced, classless and `noSteal`, like the cold beside it: it is what the body IS, not equipment, and
-- no counter deals it, no growth tally counts it and no thief lifts it.
return {
    name = "Bare Bones",
    description = "Nothing left to bleed. Holy damage breaks it.",
    flavor = "The Arcanum files these separately from the walking dead. Different shelf, different smell, different rite.",
    sprite = "assets/items/bare_bones.png",
    type = "utility",
    class = "creature",
    tags = { "dark" },
    noSteal = true, -- it is what the body IS, not equipment
    statusImmunity = { "status_bleed" },
    -- THE LATTICE IS GONE FROM HERE (2026-11-19, the creature identity pass). It used to sit on this
    -- piece -- slash 3, pierce 3, impact -6 -- which handed every skeleton in Greed the same answer: bring
    -- a mace. The audit counted five bodies asking that one question. So the bone keeps only what every
    -- dead frame shares (no blood, holy at the cap, the picture), and a skeleton's PHYSICAL line is now
    -- what it was before it died: a dwarf's race still rings under a hammer, a kobold's thin frame opens
    -- to an edge, the Bone Wyrm keeps the wyrm's hide. The lattice moved to the piece that is a dead
    -- COMPANY's (utility_company_bones.lua, the Skeleton Knight and Archer), the Barrow Lord's Binding
    -- carries its own, and the Skeleton King folds it into his innate line -- so those totals did not move.
    resist = { holy = -6 },
    wearerSkin = "bone",
}
