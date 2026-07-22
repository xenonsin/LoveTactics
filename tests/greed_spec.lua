-- The Undercroft line's two rules (docs/story.md, "The Undercroft": the rogue answers greed with
-- charity). Aurea's Golden Touch lifts the kit out of your hands (data/items/utility/utility_bottomless_purse.lua,
-- fx.steal -- the shipped half of her gold economy); Clem's Borrowed Time turns a kill into the whole
-- party's tempo, and opens only once she has collected three (data/items/weapon/weapon_borrowed_time.lua).
-- Headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Trait = require("models.trait")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

return {
    {
        name = "the Golden Touch lifts an item out of your hands, and the Purse itself cannot be taken back",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { { char = Character.instantiate("character_general_greed"), x = 2, y = 2 } },
                { { char = Character.instantiate("character_knight"), x = 3, y = 2 } })
            local aurea, victim = c.units[1], c.units[2]

            local purse = itemNamed(aurea.char, "utility_bottomless_purse")
            assert(purse, "Aurea carries her rule in her grid")
            assert(purse.noSteal, "the relic itself can never be lifted off her -- or off you, once you wear it")

            -- Her Golden Touch (Combat.steal, what the Purse's active runs) lifts a real item off a foe.
            local saved = Combat.random
            Combat.random = function() return 1 end
            local stolen = Combat.steal(c, aurea, victim)
            Combat.random = saved
            assert(stolen, "she takes the thing itself -- the clean side of the Greed/Envy line")
            assert(itemNamed(victim.char, stolen.id) == nil, "the victim no longer has it")
        end,
    },
    {
        name = "Borrowed Time opens only after Clem has collected three kills",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { { char = Character.instantiate("character_clem"), x = 1, y = 1 } },
                { { char = Character.instantiate("character_bandit"), x = 5, y = 5 } })
            local clem = c.units[1]
            local relic = clem.char.inventory[5]
            assert(relic and relic.id == "weapon_borrowed_time", "the signature sits in the center cell")

            assert(not Combat.unlockMet(clem, relic, c), "locked before she has collected")
            Combat.tally(clem, "kill", 1)
            Combat.tally(clem, "kill", 1)
            assert(not Combat.unlockMet(clem, relic, c), "still locked at two")
            Combat.tally(clem, "kill", 1)
            assert(Combat.unlockMet(clem, relic, c), "open at the third -- the mercy-stroke")
        end,
    },
}
