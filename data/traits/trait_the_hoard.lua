-- THE HOARD: what Avaritia opens her fight with (reviewed 2026-09-25, "Avaritia, the Unspent"). Carried on
-- her bound centre piece (data/items/utility/utility_the_hoard.lua) beside the Gilded Belly and her phases.
--
-- AT THE BELL:
--   * her hoard is laid around her -- Hoard.STAIR_HEAPS coin heaps within 2 of her body, less every heap the
--     company has ever carried out of her treasury in the Burglary (models/hoard.lua). What was stolen
--     before the fight is armour she does not have in it;
--   * ...and she remembers it: one stack of Every Coin Counted per heap ever taken;
--   * her wings: Wing Buffet, 2 tiles, at the start of every turn.
--
-- AND TWO STANDING FLAGS: `countsEveryCoin` (a heap the company loots in her fight is a stack at once, read
-- by the coin heap) and `emberwalk` (fire and molten gold are her ground, not a hazard to her planner).
return {
    name = "The Hoard",
    description = "Opens the fight on her hoard. Each heap taken from it increases her damage; fire and molten gold do not touch her.",
    countsEveryCoin = true,
    emberwalk = true,
    onCombatStart = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit) then return end
        local Hoard = require("models.hoard")
        local Status = require("models.status")
        local Player = require("models.player")
        local player = Player.active
        Hoard.placeHeaps(combat, unit, Hoard.stairHeaps(player), 2)
        local taken = Hoard.state(player).taken or 0
        if player and taken > 0 then
            Status.apply(combat, unit, "status_every_coin_counted", { magnitude = taken })
            ctx.log("action", string.format("%s counts what was taken from her: %d heaps.",
                (unit.char and unit.char.name) or "She", taken), unit)
        end
        Status.apply(combat, unit, "status_wing_buffet", { magnitude = 2 })
    end,
}
