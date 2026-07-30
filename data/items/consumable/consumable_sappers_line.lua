-- Sapper's Line: the alchemist half of the Saboteur (rogue x alchemist). Three charges into the ground
-- in a line, on a two-turn fuse.
--
-- Built on S3, the one system in this pass whose cost was real -- a fuse has to survive
-- models/state_hash.lua, which projects the board so two machines watching one fight can prove they
-- agree. So a charge is six numbers and never a closure, and the engine owns the single behaviour
-- ("it explodes") rather than offering a general run-this-later queue that would be an indeterminism
-- farm wearing a nicer interface.
--
-- Two turns is the bargain. It is long enough that the enemy can walk off the line if they notice, and
-- short enough that a Detonator in the other hand makes noticing not help -- which is why the two items
-- are sold on the same shelf and neither is worth much alone.
--
-- The line runs away from the sapper along whichever axis the aim leans, so it is laid across an
-- approach rather than dropped in a heap. Not tagged `potion`: the Market resells that tag and ignores
-- standing (docs/classes.md).
return {
    name = "Sapper's Line",
    description = "Buries three charges in a line, fused for two of your turns.",
    flavor = "Dug in before dawn, at the only three places anyone sensible would walk.",
    sprite = "assets/items/consumable_sappers_line.png",
    type = "consumable",
    tags = { "explosive" },
    class = "alchemist",
    discipline = "saboteur",
    price = 150,
    unlockQuests = 10,
    maxStack = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        consumesItem = true,
        description = "Plants three fused charges in a line from the aimed tile.",
        effect = function(fx)
            -- The lane runs away from the sapper: whichever axis the aim leans on, extended.
            local dx = (fx.tx > fx.user.x and 1) or (fx.tx < fx.user.x and -1) or 0
            local dy = (fx.ty > fx.user.y and 1) or (fx.ty < fx.user.y and -1) or 0
            if dx == 0 and dy == 0 then dy = 1 end
            -- Through fx.plantCharge, not Combat.plantCharge: the dry-run previews hand back an inert
            -- stand-in, so aiming this over a tile never buries a real fuse (or logs one) every frame.
            for i = 0, 2 do
                fx.plantCharge(fx.tx + dx * i, fx.ty + dy * i, { fuse = 2, amount = 12 + fx.level * 2 })
            end
        end,
    },
}
