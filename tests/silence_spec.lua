-- Tests for Silence (data/status/silenced.lua): a silenced unit cannot activate a mana ability, but
-- a stamina- or health-cost one still fires. Combat.itemBlockReason is the single gate. Headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

return {
    {
        name = "a silenced unit is refused a mana ability but keeps a stamina one",
        fn = function()
            -- One caster carrying both a mana ability (Heal) and a stamina weapon (Iron Sword).
            local char = Character.instantiate("priest")
            char.inventory = {}
            Character.addItem(char, Item.instantiate("ability_heal"))   -- mana cost
            Character.addItem(char, Item.instantiate("iron_sword"))     -- stamina cost

            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { { char = Character.instantiate("bandit"), x = 8, y = 8 } })
            local u = c.units[1]
            local heal, sword = char.inventory[1], char.inventory[2]

            -- Not silenced: both are activatable (heal has enough mana, sword enough stamina).
            assert(Combat.itemBlockReason(u, heal) == nil, "heal is usable before silence")
            assert(Combat.itemBlockReason(u, sword) == nil, "sword is usable before silence")

            Status.apply(c, u, "silenced")
            local blocked = Combat.itemBlockReason(u, heal)
            assert(blocked and blocked.kind == "silenced", "the mana ability is refused while silenced")
            assert(Combat.itemBlockReason(u, sword) == nil, "the stamina weapon still fires while silenced")
        end,
    },
    {
        name = "silence lifts when the status wears off",
        fn = function()
            local char = Character.instantiate("priest")
            char.inventory = {}
            Character.addItem(char, Item.instantiate("ability_heal"))
            local c = Combat.new(arena(8, 8), { { char = char, x = 1, y = 1 } }, { { char = Character.instantiate("bandit"), x = 8, y = 8 } })
            local u = c.units[1]
            local heal = char.inventory[1]

            Status.apply(c, u, "silenced") -- duration 8
            assert(Combat.itemBlockReason(u, heal).kind == "silenced", "silenced now")
            Status.tick(c, 8)
            assert(not Status.silenced(u), "the silence has worn off")
            assert(Combat.itemBlockReason(u, heal) == nil, "the mana ability is usable again")
        end,
    },
}
