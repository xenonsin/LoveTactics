-- UNCOMMON. The one trade on the rung the player pays or refuses TURN BY TURN rather than at pickup:
-- stand together and it is armour, stand alone and it is a hole, and which of those it is this turn is
-- decided by where you walk.
--
-- Its gaining half is trait_formation_fighter, which already exists and already measures adjacency
-- continuously; the penalty is its own trait so the two can be tuned apart.
return {
    name = "The Standing Order",
    blurb = "+%d defense while another ally stands beside you.",
    tier = "uncommon", mark = "So",
    cost = "-3 defense while no ally stands beside you.",
    scale = { 3, 2 },
    traits = { "trait_formation_fighter", "trait_standing_order_alone" },
    scope = "party",
}
