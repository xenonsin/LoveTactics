-- COMPANY BONES: what is left of a company that came down before yours -- the frame, and the drill
-- (2026-11-19, the creature identity pass). Worn by the Skeleton Knight and the Skeleton Archer.
--
-- TWO THINGS, AND BOTH ARE THE COMPANY'S RATHER THAN EVERY SKELETON'S:
--   * THE LATTICE (slash 3, pierce 3, impact -6). It used to ride Bare Bones, which handed every bone body
--     in Greed the same answer -- bring a mace -- and the audit counted five of them asking it. It lives
--     here now, on the two bodies whose fight it still is, at exactly the line they wore, so neither
--     body's total moved (tests/undead_tag_spec.lua pins it). Bare Bones keeps the picture and holy.
--   * THE DRILL (data/traits/trait_the_old_company.lua): knights Shield the bows while they stand, and the
--     bows Mark whoever holds an impact weapon. So the mace is still the answer, and the fight now also
--     asks who dies first (the knights) and who guards the answer (whoever is carrying it).
--
-- Creature kit like the bone beside it: unpriced, classless to every shelf, noSteal. It is what the body
-- IS, not equipment.
return {
    name = "Company Bones",
    description = "While a Skeleton Knight stands, its archers are Shielded. Archers Mark the nearest foe holding an impact weapon.",
    flavor = "The roll was called down here once. Nobody told them it was over.",
    sprite = "assets/items/utility_company_bones.png",
    type = "utility",
    class = "creature",
    tags = { "dark" },
    noSteal = true, -- it is what the body IS, not equipment
    resist = { slash = 3, pierce = 3, impact = -6 },
    traits = { "trait_the_old_company" },
}
