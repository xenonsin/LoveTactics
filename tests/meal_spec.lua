-- Tests for the Cafe's meals (models/meal.lua, docs/meals.md): the one-ration rule, the shape of a
-- platter, and the two seams that put a supper onto the board -- the flat courses folded in beside the
-- grid's armour, and the kitchen skill attached as an item-less trait.
--
-- Pure logic, headless. The board half runs on a real Combat, in the style of tests/trait_spec.lua.

local Meal = require("models.meal")
local Trait = require("models.trait")
local Combat = require("models.combat")
local Character = require("models.character")
local Item = require("models.item")
local Quest = require("models.quest")
local Save = require("models.save")

local function eachMeal()
    local out = {}
    for id, def in pairs(Meal.defs) do out[#out + 1] = { id = id, def = def } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

-- A minimal player, in the shape models/player.lua builds. Deliberately hand-rolled rather than
-- Player.new(): these cases are about gold, prestige and one string, and a full roster is noise.
local function fakePlayer(gold, prestige)
    return { gold = gold or 1000, prestige = prestige or 10, completedQuests = {}, stash = {},
             roster = {}, materials = {}, recipes = {}, newItems = {}, newStock = {} }
end

-- A bare walkable board, built by hand rather than through Arena.build -- these cases are about what a
-- supper does to a body, and a generated layout would drag a seed and a biome into it. Same fixture
-- shape tests/trait_spec.lua uses.
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

-- A character with an EMPTY grid, so "this body's bonuses/traits are exactly what the meal gave it" is
-- an honest claim: every sword in the game carries Parry, and a knight's own kit would muddy both.
local function plainChar()
    local char = Character.instantiate("character_knight")
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    return char
end

-- A two-body board with the party member eating `mealId` (nil for a company that did not). Returns
-- combat + the party unit.
local function boardWithMeal(mealId)
    local combat = Combat.new(arena(8, 8),
        { { char = plainChar(), x = 1, y = 1, meal = mealId and Meal.get(mealId) or nil } },
        { { char = plainChar(), x = 5, y = 5 } })
    return combat, combat.units[1]
end

return {
    -- -----------------------------------------------------------------------
    -- The menu itself
    -- -----------------------------------------------------------------------
    {
        name = "every meal declares a name, a price, a rank and something it actually does",
        fn = function()
            local meals = eachMeal()
            assert(#meals > 0, "the registry found some meals at all")
            for _, m in ipairs(meals) do
                local def = m.def
                assert(type(def.name) == "string" and def.name ~= "", m.id .. " has no name")
                assert(type(def.description) == "string" and def.description ~= "",
                    m.id .. " declares no description -- say what it DOES")
                assert(type(def.flavor) == "string" and def.flavor ~= "",
                    m.id .. " declares no flavor -- say what it MEANS")
                assert(def.flavor ~= def.description, m.id .. " uses one line for both")
                assert(type(def.price) == "number" and def.price > 0, m.id .. " has no price")
                assert(type(def.unlockPrestige) == "number" and def.unlockPrestige >= 1,
                    m.id .. " names no rank to open at")
                -- A platter that is neither courses nor a skill is a plate of nothing.
                local anything = next(def.bonus or {}) or next(def.maxBonus or {}) or next(def.resist or {})
                    or def.skill
                assert(anything, m.id .. " buys nothing at all")
            end
        end,
    },
    {
        name = "a named kitchen skill resolves to a real trait, and reads its wording off it",
        fn = function()
            for _, m in ipairs(eachMeal()) do
                if m.def.skill then
                    assert(Trait.defs[m.def.skill],
                        m.id .. " names unknown kitchen skill '" .. m.def.skill .. "'")
                    local skill = Meal.skill(m.def)
                    assert(skill and skill.name and skill.description ~= nil,
                        m.id .. "'s skill has no name/description for the counter to print")
                    assert(skill.description == Trait.defs[m.def.skill].description,
                        m.id .. "'s skill text must come off the trait, never a second copy")
                end
            end
        end,
    },
    {
        name = "the menu is ordered by rank then price, and marks what the city has not grown into",
        fn = function()
            local early = Meal.menu(1)
            assert(#early == #eachMeal(), "the whole menu is listed at any rank, locked or not")
            local prevRank, prevPrice = 0, 0
            for _, row in ipairs(early) do
                local rank = row.def.unlockPrestige or 1
                assert(rank > prevRank or (rank == prevRank and row.def.price >= prevPrice),
                    row.id .. " sorts out of order (rank, then price)")
                prevRank, prevPrice = rank, row.def.price
                assert(row.locked == (rank > 1), row.id .. " is mis-marked at prestige 1")
            end
            -- At the top of the ladder nothing is out of reach.
            for _, row in ipairs(Meal.menu(99)) do
                assert(not row.locked, row.id .. " should be on the menu by prestige 99")
            end
        end,
    },
    {
        name = "the courses read as plain labelled numbers, ceilings named as such",
        fn = function()
            local lines = Meal.courses(Meal.get("meal_black_tea_and_cardamom"))
            local joined = table.concat(lines, " | ")
            assert(joined:find("+2 Magic Damage", 1, true), "the flat course is named: " .. joined)
            -- maxBonus is a CEILING and must not read as the same thing a flat bonus does.
            assert(joined:find("+10 Max Mana", 1, true), "the ceiling raise is named: " .. joined)
            assert(#Meal.courses(nil) == 0, "no meal, no courses")
        end,
    },

    -- -----------------------------------------------------------------------
    -- The one-ration rule
    -- -----------------------------------------------------------------------
    {
        name = "you may hold exactly one meal, and buying a second is refused with a reason",
        fn = function()
            local p = fakePlayer(1000, 10)
            assert(Meal.canEat(p, "meal_macchiato"), "an unfed company may order")
            assert(Meal.eat(p, "meal_macchiato"), "the order goes through")
            assert(p.meal == "meal_macchiato", "and is held on the player")
            assert(p.gold == 1000 - Meal.get("meal_macchiato").price, "the gold is charged")

            local ok, why = Meal.eat(p, "meal_soup_in_a_crust")
            assert(not ok, "a second supper is refused")
            assert(why == "you have already eaten", "and says why, got: " .. tostring(why))
            -- The held dish answers with what it IS, not with a refusal aimed at itself.
            assert(Meal.blockReason(p, "meal_macchiato") == "this is what the company is eating",
                "the platter on the table names itself rather than refusing twice")
            assert(p.gold == 1000 - Meal.get("meal_macchiato").price,
                "a refused order charges nothing")
            assert(p.meal == "meal_macchiato", "and does not overwrite what is on the table")
        end,
    },
    {
        name = "an order is refused for rank and for gold, and charges nothing either way",
        fn = function()
            local poor = fakePlayer(10, 99)
            assert(Meal.blockReason(poor, "meal_macchiato") == "not enough gold")
            assert(not Meal.eat(poor, "meal_macchiato"))
            assert(poor.gold == 10 and poor.meal == nil, "a refusal leaves the counter untouched")

            local green = fakePlayer(9999, 1)
            assert(Meal.blockReason(green, "meal_empty_chair") == "not on the menu yet")
            assert(not Meal.eat(green, "meal_empty_chair"))
            assert(green.meal == nil)
        end,
    },
    {
        name = "completing a quest eats the meal through, and names what it spent",
        fn = function()
            local Player = require("models.player")
            local p = Player.new()
            p.gold = 1000
            assert(Meal.eat(p, "meal_morning_oats"))
            local quest = Quest.get("quest_colosseum_slot_01")
            assert(quest, "a real quest to finish")
            local reward = Quest.complete(p, quest, nil)
            assert(reward, "the quest paid out")
            assert(reward.mealSpent == "meal_morning_oats",
                "the payout names the supper it ate through")
            assert(p.meal == nil, "and the company is hungry again")
            assert(Meal.canEat(p, "meal_morning_oats"), "so the counter is open for the next run")
        end,
    },
    {
        name = "the held meal survives a save round-trip, and an unknown id does not",
        fn = function()
            local Player = require("models.player")
            local p = Player.new()
            p.gold = 1000
            assert(Meal.eat(p, "meal_soup_in_a_crust"))
            local restored = Save.restore(Save.snapshot(p))
            assert(restored.meal == "meal_soup_in_a_crust", "the supper carries across a save")

            local snap = Save.snapshot(p)
            snap.meal = "meal_that_never_existed"
            assert(Save.restore(snap).meal == nil, "a meal removed from data/ loads as nobody having eaten")
        end,
    },

    -- -----------------------------------------------------------------------
    -- What reaches the board
    -- -----------------------------------------------------------------------
    {
        name = "a meal's courses fold in beside the grid's armour, and its ceilings raise the pool",
        fn = function()
            local _, unit = boardWithMeal("meal_soup_in_a_crust")
            assert(unit.bonus.defense == 2, "the platter's defense is on the unit: "
                .. tostring(unit.bonus.defense))
            assert(unit.bonus.magicDefense == 1, "and its magic defense")

            local _, fed = boardWithMeal("meal_morning_oats")
            assert(Combat.unreservedMax(fed.char, "health")
                == (fed.char.stats.health.max + 14), "the ceiling raise reaches unreservedMax")
        end,
    },
    {
        name = "a meal's resist stacks with armour rather than replacing it",
        fn = function()
            local _, unit = boardWithMeal("meal_firewatch_pot")
            assert(unit.resist.fire == 3, "the stew wards fire")
            unit.char.inventory = { Item.instantiate("armor_salamander_hide") }
            Combat.refreshPassives(unit)
            assert(unit.resist.fire == 3 + 6,
                "coat and supper add up, got " .. tostring(unit.resist.fire))
        end,
    },
    {
        name = "the kitchen skill attaches as an item-less trait, on the whole company",
        fn = function()
            local _, unit = boardWithMeal("meal_empty_chair")
            assert(Trait.has(unit, "trait_second_wind"), "the eater carries the skill")
            for _, t in ipairs(unit.traits) do
                if t.id == "trait_second_wind" then
                    assert(t.item == nil, "a meal's skill hangs off no item -- there is nothing to unequip")
                    -- ...and with nothing to hang a tunable on either, so the supper's own sliver rides
                    -- in as instance params rather than as a second trait blueprint (Trait.param).
                    assert(t.params and t.params.revivesAt == 0.15,
                        "the dish names its own recovery, got " .. tostring(t.params and t.params.revivesAt))
                end
            end
            -- A platter with no skill grants no trait, rather than an empty one.
            local _, plain = boardWithMeal("meal_soup_in_a_crust")
            assert(#plain.traits == 0, "courses alone attach nothing")
        end,
    },
    {
        name = "the Empty Chair refuses one death a battle, and comes up on a sliver rather than half",
        fn = function()
            local combat, unit = boardWithMeal("meal_empty_chair")
            local max = Combat.unreservedMax(unit.char, "health")
            unit.char.stats.health.current = 5
            assert(Trait.trySurvive(combat, unit), "the lethal blow is refused")
            assert(unit.char.stats.health.current < math.floor(max * 0.5),
                "and it is a sliver, not a relic's half: " .. unit.char.stats.health.current)
            assert(unit.char.stats.health.current > 0, "but they are standing")
            unit.char.stats.health.current = 3
            assert(not Trait.trySurvive(combat, unit), "once a battle, and it is spent")
        end,
    },
    {
        name = "Heroics is a live threshold: nothing above half, a lot below it",
        fn = function()
            local _, unit = boardWithMeal("meal_last_cup")
            local max = Combat.unreservedMax(unit.char, "health")
            unit.char.stats.health.current = max
            assert(Trait.liveBonus(unit, "damage") == 0, "a healthy body gets nothing")
            unit.char.stats.health.current = math.floor(max * 0.4)
            assert(Trait.liveBonus(unit, "damage") == 6, "past half it is live")
            assert(Trait.liveBonus(unit, "magicDamage") == 6, "for casters too")
            -- Live means it falls back down again; a banked version would not.
            unit.char.stats.health.current = max
            assert(Trait.liveBonus(unit, "damage") == 0, "heal them and the edge goes with it")
        end,
    },
    {
        name = "a battle fought without a meal is exactly the battle it was before",
        fn = function()
            local _, unit = boardWithMeal(nil)
            assert(unit.meal == nil, "nobody ate")
            assert(next(unit.bonus) == nil, "and nothing was folded in")
            assert(#unit.traits == 0, "and nothing was attached")
        end,
    },
    {
        name = "the supper rides the bench: a member rotated in ate it too",
        fn = function()
            local combat, unit = boardWithMeal("meal_soup_in_a_crust")
            local reserve = plainChar()
            Combat.benchUnit(combat, { char = reserve, meal = unit.meal })
            local entry = combat.bench[1]
            assert(entry.meal == unit.meal, "the bench entry carries the platter")
            -- ...and so does the body it becomes. Placed by hand rather than through Combat.rotate,
            -- which needs a deploy zone and a live turn; what is under test is the carry, not the cost.
            local brought = Combat.addUnit(combat, reserve, "party", 2, 1, { meal = entry.meal })
            assert(brought.bonus.defense == 2, "a rotated-in member wears the courses")
        end,
    },
}
