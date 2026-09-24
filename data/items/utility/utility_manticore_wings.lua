-- WINGS: the Manticore's, and nothing but the `flying` tag -- Combat.isFlying scans the grid for it, so
-- the animal takes the flier's whole trade with no rule of its own: every tile costs one and unwalkable
-- ground opens, and it FORFEITS THE TILE (Combat.fieldBonus) -- no forest cover, no +20 avoid. It crosses
-- the glade fast and in the open, which is when the company's archers find its pierce weakness.
--
-- A web still catches it (hazard_web reads no flight), settled on review: a web catches birds, and its
-- planner routes round hostile ground anyway.
--
-- SHARED WITH THE WYVERN LINE (character_wyvern, _alpha, the_highwing), on review: one creature item for
-- the tag, not a second copy per animal. The id keeps the manticore's name because it was here first; the
-- item's own name has only ever said "Wings".
return {
    name = "Wings",
    description = "Flies: every tile costs 1 to cross, but it gains nothing from the ground it is over.",
    flavor = "Skin over finger-bones, like a bat's. They were not made for grace. They were made to arrive.",
    sprite = "assets/items/utility_manticore_wings.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "flying" },
    noSteal = true,
}
