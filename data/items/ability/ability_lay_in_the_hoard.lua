-- LAY IN THE HOARD: the Brood Queen lays an egg in a coin heap (character_scarab_egg). It hatches two
-- Gilded Scarabs in two turns (status_scarab_hatch) unless somebody breaks it first -- and the scarabs it
-- hatches are the ones that roll her the next heap. Reviewed 2026-09-25 ("The Coin-Eaters").
--
-- Only a heap with nobody on it: the egg is a body, and it needs the tile.
local Scarab = require("models.scarab")

return {
    name = "Lay in the Hoard",
    description = "Lays an egg in a coin heap within 3; it hatches two Gilded Scarabs in 2 turns.",
    flavor = "The gold keeps the eggs warm. Nobody has asked the gold.",
    sprite = "assets/items/ability_lay_in_the_hoard.png",
    type = "ability",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        cooldown = 15,
        support = true, -- the egg is the payload: a board change, credited to a friendly cast (AI.WEIGHTS.MUTATION)
        cost = { stat = "stamina", amount = 8 },
        aiAims = function(combat) return Scarab.heapCells(combat, true) end, -- a heap is an empty tile
        ai = { priority = "high", act = "cast", label = "a free heap is in reach",
               whenFn = function(ctx)
                   for _, h in ipairs(ctx.combat.hazards or {}) do
                       if h.alive and h.id == Scarab.HEAP then return true end
                   end
                   return false
               end },
        effect = function(fx)
            if not Scarab.heapAt(fx, fx.tx, fx.ty) or fx.unitAt(fx.tx, fx.ty) then return end
            local egg = fx.summon("character_scarab_egg", fx.tx, fx.ty, { noClaim = true })
            if type(egg) == "table" and egg.alive then
                fx.applyStatus(egg, "status_scarab_hatch")
            end
        end,
    },
}
