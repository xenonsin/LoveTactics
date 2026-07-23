-- Spiteful Caltrops: filed to a burr and steeped in something the Undercroft does not name, so a foe
-- standing in the scatter is opened rather than merely tripped. It inflicts Bleed on everything in a
-- small burst -- Bleed being the rogue's own verb (docs/classes.md, greed) -- and draws no direct
-- damage, only the wound that keeps paying as the target moves.
--
-- The pair to the Ball Bearings, and the split is deliberate: the bearings SLOW (Cripple, control), the
-- caltrops CUT (Bleed, attrition). One keeps the enemy from reaching you; the other makes reaching you
-- cost blood the whole way. Bleed here is the same status a dagger opens, so a rogue's Kingsblood follow
-- -up bites into a wound the throw already started -- the shelf reading its own verb across two items.
--
-- A THROWN consumable, not a placed trap: it applies the wound on the throw, here and now, rather than
-- lying hidden the way the hunter's caltrops (a trail-laid trap) do. Same word, different shelf -- the
-- rogue changes the ground under the cursor, the hunter seeds it in advance.
return {
    name = "Spiteful Caltrops",
    description = "Scatters barbed, tainted caltrops: Bleeds everything in a small area. Deals no direct damage.",
    flavor = "A caltrop only trips a man. The Undercroft asked what it would take to make one hold a grudge.",
    sprite = "assets/items/spiteful_caltrops.png",
    type = "consumable",
    tags = { "caltrop" },
    class = "rogue",
    price = 130,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.applyStatus(u, "status_bleed")
            end
        end,
    },
}
