-- Fire Stone: a smouldering lump with no ability of its own. Instead it radiates heat into the
-- weapons and abilities sitting adjacent to it in the 3x3 item grid (diagonals included): those
-- attacks gain the "fire" tag and set their targets alight with Burn (data/status/status_burn.lua).
-- Items that already channel water are immune to the infusion. See Combat.auraApplies / adjacencyAura
-- and the aura-fold in Combat.useItem's fx.damage.
--
-- A COATING, not a charm. `type = "consumable"`, so it carries a stack and every deliberate cast it
-- sharpens takes one off it (Combat.spendAuras; Combat.auraSpent stops an empty one applying). The
-- stone burns down.
--
-- That is the whole difference between the two kinds of aura item, and the reason both exist. A charm
-- (the Resonance Prism, Vampiric Strike) is one of nine cells committed for the rest of the campaign,
-- and has to be priced as such. A coating is a decision you make for THIS fight and re-buy for the
-- next -- which is exactly what lets it be worth more per use than any permanent fixture safely could
-- be, and what gives the Crucible something to sell you again next week. A smith sells arrows, not a
-- quiver that never empties.
--
-- A reflex does not spend one: a parry thrown with an infused blade still burns and takes nothing off
-- the stack. A coating is a thing you apply BETWEEN swings, and an answer is not a swing you had time
-- to prepare for. (Combat.spendAuras is called from the resolved-cast path alone, and says so.)
--
-- THE AURA CONTRACT (an `aura = {...}` block on any item, aggregated by adjacencyAura):
--   appliesTo   = { <item type>, ... } -- neighbor types the aura reaches ("weapon","ability","consumable")
--   requiresTags= { <tag>, ... }       -- only neighbors carrying ALL of these (Resonance Prism: "magical")
--   exceptTags  = { <tag>, ... }       -- neighbors carrying any of these are left uninfused
--   grantTags   = { <tag>, ... }       -- folded into the neighbor's attack tags (this stone: "fire")
--   status      = { id = , opts = }    -- applied to any target the neighbor's hit damages
--   amountBonus = <n>                  -- added to the neighbor's magnitude (Alchemic Mastery, Resonance Prism)
--   rangeBonus  = <n>                  -- added to the neighbor's range (Long-Fuse Reagent, Farsight Lens)
--   speedBonus  = <n>                  -- added to the initiative it bills; NEGATIVE is faster (Quickened Sigil)
--   lifesteal   = <f>                  -- share of the damage healed back (Vampiric Strike)
--   preserve    = true                 -- the neighbor consumable's own stack is not spent (Everflask)
--   careful     = true                 -- the neighbor's area spares the caster's own side (Careful Sigil)
--   twin        = true                 -- a single-target neighbor forks into a second body (Twinned Sigil)
--
-- The block is identical on a charm and on a coating. `type` alone decides whether it runs out.
return {
    name = "Fire Stone",
    description = "Adjacent weapons and abilities gain fire and inflict Burn. Spent as they are used.",
    flavor = "It smoulders whether or not anything is near it. That is the part nobody mentions.",
    sprite = "assets/items/fire_stone.png",
    type = "consumable", -- a coating: it burns down as the things beside it are used
    tags = { "fire", "coating" },
    class = "alchemist",
    price = 120,
    repRank = 1,
    aura = {
        appliesTo = { "weapon", "ability" }, -- which neighbor types the heat infuses
        exceptTags = { "water" },            -- water-aligned kit resists the infusion
        grantTags = { "fire" },              -- folded into the neighbor's attack tags
        status = { id = "status_burn", opts = { duration = 15, magnitude = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 } } }, -- applied on a damaging hit; matches Burn's own ~3 turns
    },
}
