-- Oil Flask: a thrown flask of lamp-oil that bursts over a small area and coats everything in it,
-- leaving each body Vulnerable: Fire (data/status/status_vulnerable_fire.lua) -- +10 from every fire hit
-- that follows. It does NO damage of its own; the whole payload is what the fire mage lands next.
--
-- The alchemist's exact sibling of the Acid Bomb on the same shelf, and the clean read-forwards of the
-- Rain-then-Jolt combo the game already loves: douse a cluster, then torch it. Envy's voice -- it makes
-- someone else's fire worth more rather than casting any of its own -- and a throwable, which is the
-- shelf's keyword (docs/classes.md). See docs/vulnerability.md for the family.
return {
    name = "Oil Flask",
    description = "Coats the target area, leaving everything caught in it Vulnerable: Fire.",
    flavor = "The Crucible does not sell you the fire. It sells you the reason the fire works.",
    sprite = "assets/items/oil_flask.png",
    type = "consumable",
    tags = { "oil" },
    class = "alchemist",
    price = 150,
    unlockQuests = 7,
    activeAbility = {
        target = "tile", -- thrown and bursts around the point, like the Acid Bomb
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive then fx.applyStatus(u, "status_vulnerable_fire") end
            end
        end,
    },
}
