-- The Scent Marker: a glass bulb of rendered musk, thrown to burst over a knot of the enemy. Everything
-- it splashes is Marked. It is the shelf's setup verb (docs/classes.md, gluttony: `mark`) sold as a
-- consumable, and the one that paints a WHOLE ring at once rather than a single quarry the way Mark
-- Target or the Executioner's Eye do -- the party's answer to a cluster it means to shoot through.
--
-- No damage: like every mark on this shelf, what it buys is the payoff that follows, not the throw
-- itself. It reads straight into the Marksman's Lens (ranged blows bite harder into a Marked foe) and
-- into every party follow-up, so a single bulb can set the table for a whole volley. Marks only foes --
-- an ally caught in the splash is left alone, since a mark on your own line is a wasted defense-cut.
--
-- A thrown consumable, spent on use: the fight decision reading of the mark, against the ability's
-- repeatable one. Cheap and early, because setup that costs more than the payoff is worth is setup
-- nobody buys.
return {
    name = "Scent Marker",
    description = "Bursts over an area: Marks every foe caught in it. Deals no damage.",
    flavor = "The Lodge renders it from the last kill. The next one never does understand why it was already being watched.",
    sprite = "assets/items/scent_marker.png",
    type = "consumable",
    tags = { "mark" },
    class = "hunter",
    price = 120,
    repRank = 2,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_mark")
                end
            end
        end,
    },
}
