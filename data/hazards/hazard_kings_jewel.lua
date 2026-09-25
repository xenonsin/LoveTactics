-- THE KING'S JEWEL: the Hoard-Thane's office, lying where he fell (data/traits/trait_heir_of_all.lua).
-- Round 3, 2026-09-24 ("The Dwarves of Greed"): the Arkenstone, a thing the whole line would die to hold.
--
--   * A DWARF that reaches it takes it up and becomes the HEIR OF ALL (`unit.heirOfAll`, read by
--     trait_inheritance): every Share and coffer on the board flows to it from then on.
--   * THE COMPANY that reaches it first takes it as a prize -- JEWEL_GOLD into the spoils on a win -- and
--     the line has no heir of all for the rest of the fight: Shares go back to passing to the nearest.
--   * Anybody else walks over it.
--
-- It WELCOMES a dwarf as a coin heap does, so the line runs for it on its own; nothing on the company's
-- side is told to. The race is the player's to see.
local JEWEL_GOLD = 50

return {
    name = "The King's Jewel",
    description = "The Thane's office. A dwarf that takes it up becomes heir to every fallen dwarf; the company that takes it banks it.",
    tags = { "earth" },
    duration = math.huge,
    disposition = "neutral",
    welcomes = function(unit)
        local Trait = require("models.trait")
        return unit ~= nil and unit.side ~= "party" and Trait.flag(unit, "seeksHeaps") ~= nil
    end,
    onEnter = function(ctx)
        local unit, combat = ctx.unit, ctx.combat
        if not (unit and unit.alive and combat) then return end
        local Combat = require("models.combat")
        local Trait = require("models.trait")
        local name = (unit.char and unit.char.name) or "Unit"
        if unit.side == "party" then
            ctx.consume()
            Combat.bounty(combat, JEWEL_GOLD)
            Combat.logEvent(combat, "action",
                string.format("%s takes the King's Jewel. The line has no heir.", name), unit)
        elseif Trait.flag(unit, "seeksHeaps") then
            ctx.consume()
            unit.heirOfAll = true
            Combat.logEvent(combat, "action",
                string.format("%s takes up the King's Jewel, and is heir to them all.", name), unit)
        end
    end,
}
