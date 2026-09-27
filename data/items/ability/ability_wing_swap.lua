-- WING-SWAP: every vampire's (Wrath's vampires, 2026-09-26). Trade places with any Familiar of its side on the
-- board, once every three turns -- the bat that has flown to the company's backline is where the vampire is next.
local function isFamiliar(unit, other)
    return other ~= nil and other ~= unit and other.char ~= nil and other.char.id == "character_familiar"
end

return {
    name = "Wing-Swap",
    description = "Trade places with any Familiar on your side. Once every 3 turns.",
    flavor = "A burst of leather wings where the bat was, and the vampire standing in it.",
    sprite = "assets/items/ability_wing_swap.png",
    type = "ability",
    tags = { "natural", "utility" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "ally",
        excludeSelf = true,
        onlyAt = isFamiliar,
        range = 30,
        speed = 2,
        cooldown = 15, -- three turns
        support = true,
        effect = function(fx)
            if isFamiliar(fx.user, fx.target) then fx.swap(fx.target) end
        end,
    },
}
