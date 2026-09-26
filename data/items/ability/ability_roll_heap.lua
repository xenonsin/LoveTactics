-- ROLL: the Gilded Scarab pushes a coin heap down a lane (models/scarab.lua, Scarab.roll). It merges every
-- heap it rolls over, and it stops against the first body it meets -- hurting a foe by how much gold is in
-- it, or, rolled into the Brood Queen, going into her hoard. Reviewed 2026-09-25 ("The Coin-Eaters"):
-- until the beetles came, every heap in the rift stayed where it fell.
--
-- Aimed at the HEAP, from beside it: the lane is the line from the scarab through the heap. The AI finds
-- the roll through the ordinary scorer -- a forecast blow on a foe, or a hoard handed to its Queen.
local Scarab = require("models.scarab")

return {
    name = "Roll",
    description = "Rolls an adjacent coin heap down a lane, merging heaps it crosses; it hits the first foe "
        .. "for damage by its gold.",
    flavor = "The dung beetle's trade, in a richer material.",
    sprite = "assets/items/ability_roll_heap.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "impact", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 1,
        minRange = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        aiAims = function(combat) return Scarab.heapCells(combat, false) end, -- a heap is an empty tile
        ai = { priority = "high", act = "cast", label = "a heap is on the board",
               whenFn = function(ctx)
                   for _, h in ipairs(ctx.combat.hazards or {}) do
                       if h.alive and h.id == Scarab.HEAP then return true end
                   end
                   return false
               end },
        effect = function(fx)
            Scarab.roll(fx, fx.tx, fx.ty)
        end,
    },
}
