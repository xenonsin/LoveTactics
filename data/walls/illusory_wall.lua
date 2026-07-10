-- The wall Summon Wall raises: a conjured barrier, three tiles in a line, that blocks both movement
-- and sight. Tagged `illusion`, so Dispel Illusions clears the whole span at once -- but it is solid
-- enough to be torn down the hard way too, taking a few blows apiece (models/wall.lua). It fades on
-- its own once its duration runs out, so it can never wall a battle into a permanent stalemate.
return {
    name = "Illusory Wall",
    description = "A conjured barrier. Blocks movement and line of sight until struck down or dispelled.",
    sprite = "assets/items/illusory_wall.png",
    health = 20,
    blocksMove = true,
    sightCost = 2, -- a full block on its own: no line threads through it
    duration = 18,
    tags = { "illusion", "structure" },
}
