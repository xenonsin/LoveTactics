-- Envenom: a vial of contact toxin with no ability of its own. Like the Fire Stone
-- (data/items/consumable/consumable_fire_stone.lua), through the 3x3 item grid it infuses the weapons
-- and abilities sitting adjacent to it (diagonals included): those attacks gain the "poison" tag and
-- leave their targets Poisoned (data/status/status_poison.lua) on any damaging hit. Where the Fire
-- Stone is fire, this is rot -- a slow, stacking bleed that rewards a drawn-out fight. Items already
-- carrying an antidote ("cleanse"-tagged restoratives) are left uninfused.
--
-- A COATING: `type = "consumable"`, so the vial empties as the blade beside it is used
-- (Combat.spendAuras). See the Fire Stone for the full aura contract and for why a coating and a charm
-- are deliberately different things -- this is the pair the distinction was drawn for. A vial of poison
-- that never ran out was the version of this item that made no sense, and it is the version that
-- shipped first.
--
-- Unlike the Crucible's other charms it reaches weapons and abilities, not consumables -- "adjacent
-- items deal poison." See Combat.auraApplies / adjacencyAura and the aura-fold in Combat.useItem.
local Curve = require("models.curve")

return {
    name = "Envenom",
    description = "Adjacent weapons and abilities inflict Poison on a hit. Spent as they are used.",
    flavor = "Where the Fire Stone is heat, this is rot. It rewards a fight that goes on too long.",
    sprite = "assets/items/envenom.png",
    type = "consumable", -- a coating: the vial empties as the blade beside it is used
    tags = { "poison", "coating" },
    class = "alchemist",
    discipline = "poisoner", -- deeper cut of the shelf: buyable only once the poisoner gate is cleared
    price = 175,
    unlockQuests = 6,
    aura = {
        appliesTo = { "weapon", "ability" }, -- which neighbor types the toxin coats
        exceptTags = { "restorative" },      -- a healing draught is not turned into a poison
        grantTags = { "poison" },            -- folded into the neighbor's attack tags
        status = { id = "status_poison", opts = { duration = 25, magnitude = Curve.ramp(3, 13) } }, -- applied on a damaging hit; matches Poison's own ~5 turns
    },
}
