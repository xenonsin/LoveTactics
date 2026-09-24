-- BEAR AWAY: the Highwing's chase, and the wyvern's carry worn by a person -- the carry half only, and
-- pointed either way. Take an adjacent body and fly up to three tiles with it, setting it down beside you:
--   a FOE     is taken as far from its own side as the ground allows (a healer lifted off its line)
--   an ALLY   is taken as near its own side as the ground allows (a surrounded friend lifted out)
-- The wyvern's rules hold: nothing anchored (Root, anything no shove moves) and nothing wider than a tile
-- (models/stoop.lua's Stoop.liftable). It does no harm by itself -- the wyvern's drop is the animal's.
local Stoop = require("models.stoop")

return {
    name = "Bear Away",
    description = "Carry an adjacent ally or foe up to three tiles: a foe away from its side, an ally back toward yours.",
    flavor = "It does not matter much which of you is holding on. It matters who lands where.",
    sprite = "assets/items/ability_bear_away.png",
    type = "ability",
    tags = { "wind", "movement" },
    class = "skirmisher",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "unit",
        range = 1,
        speed = 4,
        cooldown = 15,
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            local body = fx.target
            if not body or body == fx.user then return end
            if not Stoop.carry(fx, body, 3, body.side == fx.user.side) then
                if fx.log then fx.log("action", "It will not be lifted.") end
            end
        end,
    },
}
