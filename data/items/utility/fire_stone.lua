-- Fire Stone: a smoldering charm with no ability of its own. Instead it radiates heat into the
-- weapons and abilities sitting adjacent to it in the 3x3 item grid (diagonals included): those
-- attacks gain the "fire" tag and set their targets alight with Burn (data/status/burn.lua). Items
-- that already channel water are immune to the infusion. See Combat.auraApplies / adjacencyAura and
-- the aura-fold in Combat.useItem's fx.damage.
return {
    name = "Fire Stone",
    description = "A smoldering charm. Adjacent weapons and abilities gain fire and inflict Burn.",
    sprite = "assets/items/fire_stone.png",
    type = "utility",
    tags = { "fire" },
    aura = {
        appliesTo = { "weapon", "ability" }, -- which neighbor types the heat infuses
        exceptTags = { "water" },            -- water-aligned kit resists the infusion
        grantTags = { "fire" },              -- folded into the neighbor's attack tags
        status = { id = "burn", opts = { duration = 3, magnitude = 4 } }, -- applied on a damaging hit
    },
}
