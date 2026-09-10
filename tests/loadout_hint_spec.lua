-- Tests for the loadout's placement hints: Combat.adjacencyMetAt / adjacencyCandidateCells, the pure
-- reads behind the green cells ui/inventory_grid.lua paints while an item is in hand. An ability with
-- a `requiresAdjacent` (Rain of Arrows needs a bow beside it) lights only the cells where that
-- requirement would actually be met, so the player can see where it goes instead of guessing and
-- finding out in battle. Pure logic, headless.
--
-- The second half covers the other hint on that grid: Combat.auraPairCells, the ember glow that names
-- the items an aura would REACH. A requirement lights where a thing may go; an aura lights what it
-- would do once there, which is the half that is otherwise invisible until the two already touch.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")

-- A character with an empty 3x3 grid, so each case can lay out exactly the cells it cares about.
local function emptyChar(id)
    local char = Character.instantiate(id)
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

local function keys(set)
    local out = {}
    for k in pairs(set) do out[#out + 1] = k end
    table.sort(out)
    return out
end

return {
    {
        name = "adjacencyCandidateCells lights exactly the cells adjacent to a satisfying item",
        fn = function()
            local char = emptyChar("character_archer")
            -- A bow in the centre (cell 5) touches every other cell of a 3x3, so a volley works
            -- anywhere but the bow's own cell.
            char.inventory[5] = Item.instantiate("weapon_iron_bow")
            local rain = Item.instantiate("ability_rain_of_arrows")

            local cells = Combat.adjacencyCandidateCells(char, rain)
            for i = 1, 9 do
                if i == 5 then
                    assert(not cells[i], "the bow's own cell is not a candidate -- something is there")
                else
                    assert(cells[i], "cell " .. i .. " touches the centre bow, so the volley works there")
                end
            end
        end,
    },
    {
        name = "a corner bow lights only the three cells that touch it",
        fn = function()
            local char = emptyChar("character_archer")
            char.inventory[1] = Item.instantiate("weapon_iron_bow") -- top-left corner
            local rain = Item.instantiate("ability_rain_of_arrows")

            local cells = Combat.adjacencyCandidateCells(char, rain)
            -- Cell 1's neighbors in a 3x3, diagonals included: 2, 4, 5.
            assert(cells[2] and cells[4] and cells[5], "the three cells touching the corner bow light up")
            assert(not cells[1], "the bow's own cell is occupied by the bow")
            for _, i in ipairs({ 3, 6, 7, 8, 9 }) do
                assert(not cells[i], "cell " .. i .. " doesn't touch the bow: got " ..
                    table.concat(keys(cells), ","))
            end
        end,
    },
    {
        name = "with nothing to satisfy it, an ability lights no cell at all",
        fn = function()
            local char = emptyChar("character_archer")
            char.inventory[5] = Item.instantiate("armor_leather_armor") -- not a bow
            local rain = Item.instantiate("ability_rain_of_arrows")

            assert(#keys(Combat.adjacencyCandidateCells(char, rain)) == 0,
                "no bow in the grid means nowhere the volley can go")
        end,
    },
    {
        name = "an item with no adjacency requirement lights nothing (it fits anywhere)",
        fn = function()
            local char = emptyChar("character_archer")
            char.inventory[5] = Item.instantiate("weapon_iron_bow")
            -- Plain armor requires no neighbor, so there is nothing to point at: highlighting all
            -- nine cells would say exactly as much as highlighting none, and read as a false hint.
            assert(#keys(Combat.adjacencyCandidateCells(char, Item.instantiate("armor_leather_armor"))) == 0,
                "an unconstrained item lights no cells")
        end,
    },
    {
        name = "adjacencyMetAt is hypothetical: it answers for a cell the item isn't in yet",
        fn = function()
            local char = emptyChar("character_archer")
            char.inventory[1] = Item.instantiate("weapon_iron_bow")
            local rain = Item.instantiate("ability_rain_of_arrows")

            assert(Combat.adjacencyMetAt(char, rain, 2), "cell 2 touches the bow at cell 1")
            assert(not Combat.adjacencyMetAt(char, rain, 9), "cell 9 is across the grid from it")

            -- The item need not be in the grid at all -- which is the whole point while it is in hand.
            assert(Character.slotIndex(char, rain) == nil, "the volley is still in the stash")
        end,
    },
    {
        name = "an item never counts as its own neighbor",
        fn = function()
            local char = emptyChar("character_archer")
            local rain = Item.instantiate("ability_rain_of_arrows")
            char.inventory[5] = rain -- already placed, with no bow anywhere
            assert(not Combat.adjacencyMetAt(char, rain, 4),
                "the volley sitting next door is not a bow, and cannot satisfy itself")
            assert(not Combat.adjacencyMet(char, rain), "so the real gate refuses it too")
        end,
    },
    {
        name = "the lit cells agree with the gate that will actually judge the cast",
        fn = function()
            -- The hint must never promise a placement Combat.adjacencyMet would then refuse: the two
            -- reads have to agree cell for cell, or a green cell becomes a lie.
            local char = emptyChar("character_archer")
            char.inventory[3] = Item.instantiate("weapon_iron_bow")
            local rain = Item.instantiate("ability_rain_of_arrows")
            local cells = Combat.adjacencyCandidateCells(char, rain)

            for i = 1, 9 do
                if char.inventory[i] == nil then
                    char.inventory[i] = rain
                    local met = Combat.adjacencyMet(char, rain)
                    char.inventory[i] = nil
                    assert((cells[i] or false) == met,
                        "cell " .. i .. ": the hint and the gate disagree")
                end
            end
        end,
    },
    {
        name = "auraPairCells lights the kit an aura would reach, and nothing it wouldn't",
        fn = function()
            local char = emptyChar("character_archer")
            char.inventory[1] = Item.instantiate("weapon_iron_sword")       -- weapon: blessed
            char.inventory[2] = Item.instantiate("ability_rain_of_arrows")  -- ability: blessed
            char.inventory[3] = Item.instantiate("armor_leather_armor")     -- armor: not in appliesTo
            char.inventory[4] = Item.instantiate("consumable_healing_potion") -- nor a draught
            local censer = Item.instantiate("utility_censer_of_dawn")

            local cells = Combat.auraPairCells(char, censer)
            assert(cells[1] and cells[2], "the censer's blessing reaches a weapon and an ability")
            assert(not cells[3] and not cells[4],
                "it reaches neither armor nor a potion: got " .. table.concat(keys(cells), ","))
            assert(not cells[9], "an empty cell holds nothing to gain")
        end,
    },
    {
        name = "the glow reads both ends of a pairing: the aura held, and the aura already worn",
        fn = function()
            -- The player asking "what does this go with" is asking one question, and the answer must
            -- not depend on which of the two pieces happens to be in hand.
            local char = emptyChar("character_archer")
            char.inventory[5] = Item.instantiate("consumable_fire_stone") -- an aura already in the grid
            local sword = Item.instantiate("weapon_iron_sword")           -- and a plain blade in hand

            assert(Combat.auraPairCells(char, sword)[5],
                "the stone that would infuse this blade lights up, though the blade carries no aura")
        end,
    },
    {
        name = "an exception is not a pairing -- exceptTags kit stays dark",
        fn = function()
            -- Hand-built rather than instantiated: the censer's carve-out is `shadow`, and no shipped
            -- WEAPON carries that tag today (the only one is a utility relic, which the aura does not
            -- reach anyway). A case that could only pass would prove nothing about the filter, so the
            -- input is written out here -- the same plain shape Combat.auraApplies reads off an item.
            local char = emptyChar("character_archer")
            char.inventory[1] = Item.instantiate("weapon_iron_sword")
            char.inventory[2] = { id = "weapon_shadow_test", name = "Shadow Blade",
                type = "weapon", tags = { "sword", "shadow" } }
            local censer = Item.instantiate("utility_censer_of_dawn")

            local cells = Combat.auraPairCells(char, censer)
            assert(cells[1], "the plain blade is blessed")
            assert(not cells[2], "kit that already channels shadow refuses the blessing, and stays dark")
        end,
    },
    {
        name = "an item with no aura at either end lights nothing",
        fn = function()
            local char = emptyChar("character_archer")
            char.inventory[1] = Item.instantiate("weapon_iron_sword")
            char.inventory[5] = Item.instantiate("armor_leather_armor")
            assert(#keys(Combat.auraPairCells(char, Item.instantiate("weapon_iron_bow"))) == 0,
                "two plain weapons and a coat make no pairing to promise")
        end,
    },
    {
        name = "a glowing cell is a wire the grid will really draw once the two touch",
        fn = function()
            -- The mark is drawn in the aura wire's own colour, so it promises that wire. Walk the
            -- censer into every free cell and check the two reads agree: a cell that glows must produce
            -- an "aura" link the moment the censer lands beside it, and one that doesn't must not.
            local char = emptyChar("character_archer")
            char.inventory[1] = Item.instantiate("weapon_iron_sword")
            char.inventory[9] = Item.instantiate("armor_leather_armor")
            local censer = Item.instantiate("utility_censer_of_dawn")
            local glowing = Combat.auraPairCells(char, censer)

            for cell = 1, 9 do
                if char.inventory[cell] == nil then
                    char.inventory[cell] = censer
                    local wired = {}
                    for _, link in ipairs(Combat.adjacencyLinks(char)) do
                        if link.kind == "aura" and link.from == cell then wired[link.to] = true end
                    end
                    char.inventory[cell] = nil
                    for _, other in ipairs({ 1, 9 }) do
                        local adjacent = false
                        for _, i in ipairs(Character.adjacentIndices(cell)) do
                            if i == other then adjacent = true end
                        end
                        -- Adjacent AND glowing is exactly the wire; anything else draws none.
                        assert((wired[other] or false) == (adjacent and (glowing[other] or false)),
                            "censer in cell " .. cell .. ": the glow on cell " .. other ..
                                " disagrees with the wire")
                    end
                end
            end
        end,
    },
}
