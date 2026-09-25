-- GILD: pour molten gold over a crowd (reviewed 2026-09-25, "Avaritia, the Unspent"; re-pitched the same
-- day on the choice "Existing Gilded" -- it lands the dwarves' own Gilded, and it is not Gilder's Leaf
-- because it takes a whole square of foes at once and is paid for in gold).
--
-- Consume 30 gold: every foe in a 3x3 is Gilded -- slowed, and worth 20 gold if it falls gilded, so a
-- crowd gilded and cut down pays the pour back. Her melted hoard, in a company's hands.
--
-- A general's find: `unstocked`, on the mammonite's rack (the house that spends its gold as a weapon).
local PRICE = 30

return {
    name = "Gild",
    description = "Consume 30 gold: every foe in the area is Gilded.",
    flavor = "It hardens before they understand what it is, and they are worth more for it.",
    sprite = "assets/items/ability_gild.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mammonite",
    unlockLevel = 6,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 4,
        cooldown = 15,
        aoe = { radius = 1 },
        usable = function(unit)
            local combat = unit and unit.combat
            if combat and require("models.combat").purseAvailable(combat, unit) < PRICE then
                return false, "Not enough gold"
            end
            return true
        end,
        effect = function(fx)
            local foes = {}
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive and u.side ~= fx.user.side then foes[#foes + 1] = u end
            end
            if #foes == 0 then return end
            if fx.spendPurse(PRICE) < PRICE then return end
            for _, u in ipairs(foes) do fx.applyStatus(u, "status_gilded") end
        end,
    },
}
