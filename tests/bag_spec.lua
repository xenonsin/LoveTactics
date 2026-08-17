-- Tests for BAGS (models/item.lua's Item.bagRoom / bagPut / bagTake / bagIn) and the branch they were
-- built for in Combat.steal.
--
-- The bag exists because a lift had nowhere to go: Combat.steal tries the thief's grid and then fell
-- through to the party stash, which is OUT of the battle. On a nine-cell grid already carrying a
-- build that made "steal it" mostly mean "remove it from play" -- fine for a denial tool, useless for
-- a signature whose payoff is using what you took. So the ordering below is the whole point of the
-- feature and is pinned here: grid first, then the bag, and only then the stash.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")

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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function strip(char)
    for _, it in ipairs(Character.eachItem(char)) do Character.removeItem(char, it) end
end

-- A bag with a capacity of two, built by hand: the relic that carries one is authored later, and this
-- file is about the container rather than about Pim.
local function makeBag(capacity)
    return { id = "test_bag", name = "Test Bag", type = "utility",
             bag = { capacity = capacity }, contents = {} }
end

return {
    {
        name = "a bag reports its room, fills, and empties",
        fn = function()
            local bag = makeBag(2)
            assert(Item.bagRoom(bag) == 2, "an empty bag is all room")
            -- Anything that is not a bag answers 0 rather than nil, so a caller can ask any item.
            assert(Item.bagRoom(Item.instantiate("weapon_iron_sword")) == 0, "a sword holds nothing")
            assert(Item.bagRoom(nil) == 0, "and neither does nothing")

            local a = Item.instantiate("weapon_iron_sword")
            local b = Item.instantiate("consumable_healing_potion")
            assert(Item.bagPut(bag, a), "the first goes in")
            assert(Item.bagPut(bag, b), "and so does the second")
            assert(Item.bagRoom(bag) == 0, "which fills it")
            assert(not Item.bagPut(bag, Item.instantiate("weapon_iron_sword")), "a full bag refuses")

            assert(Item.bagTake(bag, a), "the sword comes back out")
            assert(Item.bagRoom(bag) == 1, "leaving room")
            assert(not Item.bagTake(bag, a), "and it cannot come out twice")
        end,
    },
    {
        name = "a bag never goes inside a bag",
        fn = function()
            local outer, inner = makeBag(2), makeBag(2)
            assert(not Item.bagPut(outer, inner), "refused")
            -- Not tidiness: every reader walks `contents` one level deep, so a nested bag would hide
            -- its own contents from the panel, from the census and from the payoff that empties it.
            assert(Item.bagRoom(outer) == 2, "and nothing was consumed by the refusal")
        end,
    },
    {
        name = "Item.bagIn finds the first bag in a grid with room, in grid order",
        fn = function()
            local char = Character.instantiate("character_rogue")
            strip(char)
            assert(Item.bagIn(char) == nil, "no bag, no answer")

            local full, roomy = makeBag(1), makeBag(1)
            Character.addItem(char, full)
            Character.addItem(char, roomy)
            Item.bagPut(full, Item.instantiate("weapon_iron_sword"))

            assert(Item.bagIn(char) == roomy, "the full one is skipped for the one with room")
            Item.bagPut(roomy, Item.instantiate("weapon_iron_sword"))
            assert(Item.bagIn(char) == nil, "and when both are full there is no answer at all")
        end,
    },
    {
        name = "a theft goes to the grid first, the bag second, the stash last",
        fn = function()
            local thief = unit("character_rogue", 1, 1)
            local victim = unit("character_bandit", 2, 1)
            strip(thief.char)
            strip(victim.char)

            local bag = makeBag(1)
            Character.addItem(thief.char, bag)
            -- Fill every remaining cell so the grid cannot take the lift, leaving the bag as the only
            -- thing standing between the stolen item and a stash that is out of the fight.
            while Character.addItem(thief.char, Item.instantiate("consumable_healing_potion")) do end

            for _ = 1, 3 do Character.addItem(victim.char, Item.instantiate("weapon_iron_sword")) end

            local c = Combat.new(arena(8, 8), { thief }, { victim })
            c.stash = {}
            local t, v = c.units[1], c.units[2]

            local first = Combat.steal(c, t, v)
            assert(first, "something was lifted")
            assert(#bag.contents == 1 and bag.contents[1] == first,
                "with no cell free, the bag catches it -- not the stash")
            assert(#c.stash == 0, "and the stash stays empty")

            -- Bag full AND grid full: only now does the stash get it. This is the old behaviour, kept
            -- as the last resort rather than removed -- the item is still the party's, just not hers.
            local second = Combat.steal(c, t, v)
            assert(second, "a second lift")
            assert(#bag.contents == 1, "the bag is still full")
            assert(#c.stash == 1 and c.stash[1] == second, "so this one goes to the stash")
        end,
    },
    {
        name = "a bag instantiated from a blueprint arrives with its own contents table",
        fn = function()
            -- Item.instantiate creates `contents` for anything declaring `bag`, so an empty bag is a
            -- bag: every reader can count it without first checking whether anything was put in.
            local def = { name = "Sack", type = "utility", bag = { capacity = 3 } }
            Item.defs["test_sack"] = def
            local made = Item.instantiate("test_sack")
            assert(type(made.contents) == "table", "contents exists")
            assert(Item.bagRoom(made) == 3, "and the capacity carried over")
            Item.defs["test_sack"] = nil
        end,
    },
}
