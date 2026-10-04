-- ICE WALL: a pane of the Snow Queen's Glass Palace ("Sloth's Bestiary", 2026-10-04, approved: "cutting the board
-- into rooms; fire melts a wall"). Risen out of hazard_rising_ice, three panes a turn.
--
-- GLASS, SO IT STOPS A STEP AND NOT A LOOK (`sightCost = 0`): the rooms are rooms to walk, and the company can still
-- see its healer through the pane it cannot reach her across. What the Palace cuts off is the hand, which is the
-- same thing her splinter cuts off.
--
-- FIRE MELTS IT WHOLE (`meltsUnder`, Wall.meltIn): a fire cast whose footprint covers it, or a fire blow struck at
-- it. Anything else breaks it down the slow way, and it fades on its own after five turns so the board never seals
-- for good.
return {
    name = "Ice Wall",
    description = "A pane of the Glass Palace. Blocks movement, not sight. Fire melts it.",
    sprite = "assets/items/ice_wall.png",
    health = 18,
    blocksMove = true,
    sightCost = 0,
    duration = 25,
    meltsUnder = { "fire" },
    tags = { "ice", "structure" },
}
