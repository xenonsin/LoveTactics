-- The Gillscale Wrap: naga scale, cut from a body and bound into something a person can wear.
--
-- THE PIECE THE WHOLE FACTION EXISTS TO HAND OVER. It carries the `swim` tag, which is the one thing
-- Combat.isAquatic looks for -- so the wearer enters the ford and the deep channel at a flat 1, may
-- STOP in either, and cannot drown. On a fen board, where the walls of the arena are water, that turns
-- the board inside out: the ground the Mere fought you from becomes the ground you flank them from.
--
-- IT IS THE ZEPHYR STRIDERS' SMALLER COUSIN AND MUST NEVER BE TIERED AS THEIR EQUAL. The Striders open
-- EVERY tile and charge 1 everywhere, which is why their own file calls them the strongest movement
-- item in the game: what they remove is not a penalty but a MAP. This opens exactly two tiles and
-- charges 1 on those. What it buys is a lane, not a map -- and on the majority of boards, which have
-- no water on them at all, it buys nothing whatsoever. That is the trade, and it is the reason the two
-- can sit on the same shelf without one deleting the other.
--
-- `dropOnly` (models/vendor.lua): no counter in the city will ever deal one. It is on the rack, greyed,
-- under "monster drop" -- visible so a player can learn it exists without having met a naga, refused so
-- the only road to it is the one the bestiary names. It still sells back at the usual half like any
-- other found ware; the Mere's kit is not merchandise, but it is not worthless either.
--
-- THE DEPTH IS HAND-PLACED and that is not an oversight. models/grade.lua values a movement RULE at
-- close to nothing -- it prices magnitudes, and this piece's whole payload is a sentence about which
-- tiles exist for you -- so `. drop-tier` grades it near the bottom of the ladder and would deal the
-- best drop in the fen out of floor one. The same allowance a tag-immunity carries, for the same
-- reason, written down here rather than rediscovered later.
--
-- `class = "rogue"` is the shelf it files under rather than a claim about who may wear it -- anyone
-- carries anything (docs/classes.md), and the rogue rack is where every movement utility in the game
-- already lives, the Striders included.
return {
    name = "Gillscale Wrap",
    description = "Water costs one tile to cross and deep water can be entered. You cannot drown.",
    flavor = "The scales still lie the right way. Whoever bound them knew which way was down.",
    sprite = "assets/items/gillscale_wrap.png",
    type = "utility",
    tags = { "swim" },
    class = "rogue",
    dropOnly = true,
    -- HAND-PLACED, and `. drop-tier` says 1. See the header: grade prices magnitudes, and this
    -- piece's whole payload is a sentence about which tiles exist for you -- so the best drop in
    -- the fen would fall out of floor one. Deep enough that the Mere is a real fight first.
    dropTier = 4,
    unlockQuests = 4,
}
