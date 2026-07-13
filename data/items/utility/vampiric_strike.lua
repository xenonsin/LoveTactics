-- Vampiric Strike: a passive charm, not an attack of its own. It infuses the WEAPONS sitting adjacent
-- to it in the 3x3 item grid (diagonals included) with a thirst -- every time one of them lands a
-- blow, its wielder heals for a share of the damage dealt. Build the loadout around it: put a blade
-- (or three) beside it and each swing mends you. Works exactly like the Fire Stone / Envenom auras
-- (Combat.auraApplies / adjacencyAura), through the new `lifesteal` fold in Combat.useItem's fx.damage.
return {
    name = "Vampiric Strike",
    description = "Adjacent weapons drink: their strikes heal you for a share of the damage dealt.",
    sprite = "assets/items/vampiric_strike.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    price = 300,
    repRank = 3,
    aura = {
        appliesTo = { "weapon" }, -- only the blades it sits beside gain the thirst
        lifesteal = 0.5,          -- the wielder heals 50% of each infused hit's damage
    },
}
