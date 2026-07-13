-- Envenom: a vial of contact toxin with no ability of its own. Like the Fire Stone
-- (data/items/utility/fire_stone.lua), through the 3x3 item grid it infuses the weapons and abilities
-- sitting adjacent to it (diagonals included): those attacks gain the "poison" tag and leave their
-- targets Poisoned (data/status/poison.lua) on any damaging hit. Where the Fire Stone is fire, this
-- is rot -- a slow, stacking bleed that rewards a drawn-out fight. Items already carrying an antidote
-- ("cleanse"-tagged restoratives) are left uninfused.
--
-- Unlike the Crucible's other charms it reaches weapons and abilities, not consumables -- "adjacent
-- items deal poison." See Combat.auraApplies / adjacencyAura and the aura-fold in Combat.useItem.
return {
    name = "Envenom",
    description = "A contact toxin. Adjacent weapons and abilities inflict Poison on a hit.",
    sprite = "assets/items/envenom.png",
    type = "utility",
    tags = { "poison" },
    class = "alchemist",
    price = 260,
    repRank = 2,
    aura = {
        appliesTo = { "weapon", "ability" }, -- which neighbor types the toxin coats
        exceptTags = { "restorative" },      -- a healing draught is not turned into a poison
        grantTags = { "poison" },            -- folded into the neighbor's attack tags
        status = { id = "poison", opts = { duration = 5, magnitude = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 } } }, -- applied on a damaging hit
    },
}
