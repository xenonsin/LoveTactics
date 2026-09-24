-- WOOD-WALKER: the Sabertooth crosses rough ground as if it were open. Approved in round two while the
-- forest was its cover, and kept in round three as a movement perk once it was not.
--
-- IT RIDES THE TRACKLESS BOOTS' FIELD (`terrainEase = 1`, Combat.terrainEase) rather than a forest-only
-- rule of its own, so it eases every rough tile and not just the wood -- in the wood that is the trees and
-- the hills. One field that already means "the most the ground may charge this body" beats a second one
-- that means the same thing about one terrain.
return {
    name = "Wood-Walker",
    description = "Rough ground costs no more than open ground to cross.",
    flavor = "It walks through a thicket the way you walk through a doorway.",
    sprite = "assets/items/utility_wood_walker.png",
    type = "utility",
    class = "creature",
    tags = { "beast" },
    noSteal = true,
    terrainEase = 1,
}
