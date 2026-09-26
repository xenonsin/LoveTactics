-- CARRY HOME: the Gilded Scarab rolls a heap beside it TOWARD its Brood Queen rather than away from itself
-- (models/scarab.lua -- the same roll, pointed home). A heap that reaches her goes into her Hoard, and the
-- Hoard is floor five's clock (ability_roll_the_hoard). Reviewed 2026-09-25 ("The Coin-Eaters").
--
-- A SEPARATE VERB FROM ROLL, AND FOR THE PLANNER'S SAKE. Roll is a blow -- the scorer weighs the gold it
-- hits a foe with. Carrying gold home hits nobody, so it is a SUPPORT cast: its payload is the board, which
-- the scorer credits for a friendly cast (AI.WEIGHTS.MUTATION) and never for a hostile one. Folded into
-- Roll, the first heap into her would have scored and every one after it would have scored nothing, since
-- a buff she already wears counts for nothing -- and the clock would never have run.
--
-- It is a real roll, so the counterplay stands: a body in the lane stops it short of her.
local Scarab = require("models.scarab")

return {
    name = "Carry Home",
    description = "Rolls an adjacent coin heap toward its Queen; a heap that reaches her joins her Hoard.",
    flavor = "Everything the colony finds, it brings back. Everything.",
    sprite = "assets/items/ability_carry_home.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "impact", "physical" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        range = 1,
        minRange = 1,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 4 },
        aiAims = function(combat) return Scarab.heapCells(combat, false) end, -- a heap is an empty tile
        ai = { priority = "urgent", act = "cast", label = "its Queen is on the board, and so is gold",
               whenFn = function(ctx)
                   if not Scarab.hoarderFor(ctx.combat, ctx.unit.side, ctx.unit.x, ctx.unit.y) then return false end
                   for _, h in ipairs(ctx.combat.hazards or {}) do
                       if h.alive and h.id == Scarab.HEAP then return true end
                   end
                   return false
               end },
        effect = function(fx)
            local queen = fx.combat and Scarab.hoarderFor(fx.combat, fx.user.side, fx.tx, fx.ty)
            if not queen then return end
            local dx, dy, reach = Scarab.toward(fx.tx, fx.ty, queen)
            if dx == 0 and dy == 0 then return end
            Scarab.roll(fx, fx.tx, fx.ty, dx, dy, reach)
        end,
    },
}
