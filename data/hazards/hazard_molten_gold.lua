-- MOLTEN GOLD: Avaritia's hoard, melted (reviewed 2026-09-25, "Avaritia, the Unspent"). Her fire turns any
-- coin heap it crosses into this (models/hoard.lua's burnCells), and at a third of her health the whole of
-- what is left melts at once (her phase relic's `ground` response).
--
-- IT BURNS, AND IT GILDS. Entering it sets Burn, as fire does; ending a turn in it leaves the body Gilded
-- (status_in_molten_gold, zone-bound). It lasts the fight, and it gives her no Gilded Belly: the belly
-- counts coin heaps, and molten gold is not one. So her own fire ruins her own armour, and the board narrows
-- as the fight goes on.
--
-- Walked through freely by whatever fire does not touch: the dragon herself and a body in Emberwalk Greaves
-- both carry the `emberwalk` flag, and `welcomes` keeps their planners from treating it as ground to avoid.
local BURN = 4

local function unbothered(unit)
    local Trait = require("models.trait")
    return unit ~= nil and Trait.flag(unit, "emberwalk") ~= nil
end

return {
    name = "Molten Gold",
    description = "Melted hoard. Inflicts Burn on units that enter; a unit that ends its turn here is Gilded.",
    tags = { "fire" },
    duration = math.huge,
    disposition = "hostile",
    welcomes = unbothered,
    onEnter = function(ctx)
        local unit = ctx.unit
        if not (unit and unit.alive) or unbothered(unit) then return end
        ctx.applyStatus(unit, "status_burn", { magnitude = ctx.amount or BURN })
        ctx.applyStatus(unit, "status_in_molten_gold")
    end,
}
