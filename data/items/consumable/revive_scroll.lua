-- A one-use scroll of resurrection: the Revive spell (data/items/ability/ability_revive.lua) packed
-- into a consumable anyone can carry -- the party's answer to a fallen member without a priest on the
-- field. Shorter reach than the spell (range 1: you must stand beside the body), and spent on use.
-- Raises the SAME fallen ally where they lie at half health, only while no one stands on the tile.
return {
    name = "Scroll of Revival",
    description = "Raise an adjacent fallen ally at half health. Consumed on use.",
    sprite = "assets/items/revive_scroll.png",
    type = "consumable",
    tags = { "scroll", "restorative" },
    class = "priest",
    price = 220,
    repRank = 3,
    activeAbility = {
        name = "Unfurl",
        target = "tile",
        support = true, -- friendly cast: preview green
        range = 1,      -- must be adjacent to the body
        power = { 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 },     -- percent of health restored
        speed = 4,
        consumesItem = true,
        effect = function(fx)
            local corpse = fx.corpseAt(fx.tx, fx.ty)
            if corpse and corpse.side == fx.user.side then
                fx.reanimate(corpse, (fx.power or 50) / 100)
            end
        end,
    },
}
