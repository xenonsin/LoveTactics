-- Vampiric Strike: a passive charm, not an attack of its own. It infuses the WEAPONS sitting adjacent
-- to it in the 3x3 item grid (diagonals included) with a thirst -- every time one of them lands a
-- blow, its wielder heals for a share of the damage dealt. Build the loadout around it: put a blade
-- (or three) beside it and each swing mends you. Works exactly like the Fire Stone / Envenom auras
-- (Combat.auraApplies / adjacencyAura), through the new `lifesteal` fold in Combat.useItem's fx.damage.
return {
    name = "Vampiric Strike",
    description = "Adjacent weapons heal you on the damage they deal.",
    flavor = "Put a blade beside it, or three. Each swing mends what the last one cost you.",
    sprite = "assets/items/vampiric_strike.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "barbarian", -- deeper cut of the shelf: buyable only once the barbarian gate is cleared
    price = 440,
    unlockQuests = 6,
    aura = {
        appliesTo = { "weapon" }, -- only the blades it sits beside gain the thirst
        lifesteal = 0.5,          -- the wielder heals 50% of each infused hit's damage
    },
}
