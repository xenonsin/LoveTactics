-- A one-use scroll of resurrection: the Revive spell (data/items/ability/ability_revive.lua) packed
-- into a consumable anyone can carry -- the party's answer to a fallen member without a priest on the
-- field. Shorter reach than the spell (range 1: you must stand beside the body), and spent on use.
-- Raises the SAME fallen ally where they lie at half health, only while no one stands on the tile.
local Curve = require("models.curve")

return {
    name = "Scroll of Revival",
    description = "Raises an adjacent fallen ally, restoring part of their health.",
    flavor = "The priest will tell you the words are the easy part. Standing over the body is the rest of it.",
    sprite = "assets/items/revive_scroll.png",
    type = "consumable",
    tags = { "scroll", "restorative" },
    class = "priest",
    price = 320,
    unlockQuests = 12,
    activeAbility = {
        target = "tile",
        support = true, -- friendly cast: preview green
        range = 1,      -- must be adjacent to the body
        reviveHealth = Curve.ramp(50),     -- percent of health restored
        speed = 4,
        consumesItem = true,
        effect = function(fx)
            -- The incapacitated body on the tile (still inside its window); a corpse gone cold is past
            -- reviving and fx.downedAt no longer returns it.
            local body = fx.downedAt(fx.tx, fx.ty)
            if body and body.side == fx.user.side then
                fx.reanimate(body, (fx.amount or 50) / 100)
            end
        end,
    },
}
