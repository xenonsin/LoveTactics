-- Fire Stone: a smoldering charm with no ability of its own. Instead it radiates heat into the
-- weapons and abilities sitting adjacent to it in the 3x3 item grid (diagonals included): those
-- attacks gain the "fire" tag and set their targets alight with Burn (data/status/burn.lua). Items
-- that already channel water are immune to the infusion. See Combat.auraApplies / adjacencyAura and
-- the aura-fold in Combat.useItem's fx.damage.
--
-- The aura contract (an `aura = {...}` block on any utility item, aggregated by adjacencyAura):
--   appliesTo  = { <item type>, ... } -- neighbor types the aura reaches ("weapon","ability","consumable")
--   exceptTags = { <tag>, ... }       -- neighbors carrying any of these are left uninfused
--   grantTags  = { <tag>, ... }       -- folded into the neighbor's attack tags (this stone: "fire")
--   status     = { id = , opts = }    -- applied to any target the neighbor's hit damages
--   powerBonus = <n>                  -- added to the neighbor's ability Power (Alchemic Mastery)
--   rangeBonus = <n>                  -- added to the neighbor's ability range (Long-Fuse Reagent)
--   preserve   = true                 -- the neighbor consumable's stack is not spent on use (Everflask)
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
        status = { id = "burn", opts = { duration = 3, magnitude = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 } } }, -- applied on a damaging hit
    },
}
