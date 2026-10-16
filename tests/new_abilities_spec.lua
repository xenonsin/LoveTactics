-- The two abilities a root unlock hands over that the shelves did not already carry (the class-unlock
-- design, 2026-10-15): the Knight's Brace and the Alchemist's Quick Brew. Both are rung 1, 125g.

local Combat = require("models.combat")
local Character = require("models.character")
local Item = require("models.item")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

local function countOf(char, id)
    local n = 0
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then n = n + (it.quantity or 1) end
    end
    return n
end

local function knightPair()
    local map = Fixture.new(10, 10)
    local knight = Fixture.unit("character_rowan", 3, 3, { isolate = "bare", items = { "ability_brace" } })
    local ally = Fixture.unit("character_ren", 3, 4, { isolate = "bare" })
    local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
    local combat = Combat.new(map, { knight, ally }, { foe })
    local k, a = combat.units[1], combat.units[2]
    k.char.stats.stamina.max, k.char.stats.stamina.current = 99, 99
    return combat, k, a
end

return {
    {
        name = "ability_brace sits on the knight's first rung at 125g",
        fn = function()
            local def = Item.defs["ability_brace"]
            assert(def and def.class == "knight" and def.unlockLevel == 1 and def.price == 125,
                "Brace is a rung-1 knight ware at 125g")
            local ab = def.activeAbility
            assert(ab.target == "ally" and ab.range == 1 and ab.speed == 2 and ab.support,
                "an ally (self included) one tile off, at speed 2, as a support cast")
            assert(ab.cost.stat == "stamina" and ab.cost.amount == 10, "it costs 10 stamina")
        end,
    },
    {
        name = "Brace stands the knight and the ally beside it in the Defending stance at +6",
        fn = function()
            local combat, k, a = knightPair()
            local ok = Fixture.strike(combat, k, a, "ability_brace")
            assert(ok, "Brace is cast on the adjacent ally")
            local own, lent = Status.get(k, "status_defending"), Status.get(a, "status_defending")
            assert(own and own.magnitude == 6, "the knight is Defending at +6")
            assert(lent and lent.magnitude == 6, "and so is the ally")
            assert(lent.heldBy == k and not own.heldBy, "the ally's brace is the knight's to hold")
            assert(k.char.stats.stamina.current < 99, "stamina is paid for it")
        end,
    },
    {
        name = "Brace's lent stance outlasts the ally's turn and ends at the knight's next",
        fn = function()
            local combat, k, a = knightPair()
            assert(Fixture.strike(combat, k, a, "ability_brace"), "Brace is cast")
            Status.onTurnStart(combat, a)
            assert(Status.has(a, "status_defending"), "the ally's own turn start leaves the brace standing")
            Status.onTurnStart(combat, k)
            assert(not Status.has(k, "status_defending"), "the knight's next turn ends its own stance")
            assert(not Status.has(a, "status_defending"), "and takes down the one it lent")
        end,
    },
    {
        name = "Brace cast on yourself braces only you, and never lowers a harder guard",
        fn = function()
            local combat, k, a = knightPair()
            assert(Fixture.strike(combat, k, k, "ability_brace"), "Brace on the caster")
            assert(Status.get(k, "status_defending").magnitude == 6, "the knight braces")
            assert(not Status.has(a, "status_defending"), "the ally beside it was not the target")

            local combat2, k2, a2 = knightPair()
            Status.apply(combat2, a2, "status_defending", { magnitude = 10 })
            assert(Fixture.strike(combat2, k2, a2, "ability_brace"), "Brace on an already-braced ally")
            local st = Status.get(a2, "status_defending")
            assert(st.magnitude == 10 and not st.heldBy, "the ally keeps its own harder stance")
        end,
    },
    {
        name = "ability_quick_brew sits on the alchemist's first rung, once a battle",
        fn = function()
            local def = Item.defs["ability_quick_brew"]
            assert(def and def.class == "alchemist" and def.unlockLevel == 1 and def.price == 125,
                "Quick Brew is a rung-1 alchemist ware at 125g")
            local ab = def.activeAbility
            assert(ab.speed == 3 and ab.cost.stat == "mana" and ab.cost.amount == 10, "speed 3, 10 mana")
            assert((ab.cooldown or 0) >= 999, "a cooldown no fight outlasts: once per battle")
        end,
    },
    {
        name = "Quick Brew puts a Healing Potion in an empty cell, and cannot be cast twice",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3, { isolate = "bare", items = { "ability_quick_brew" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            assert(Fixture.strike(combat, h, h, "ability_quick_brew"), "it is brewed")
            assert(countOf(h.char, "consumable_healing_potion") == 1, "a Healing Potion is in the grid")
            local again = Fixture.strike(combat, h, h, "ability_quick_brew")
            assert(not again, "the brew is once a battle")
            assert(countOf(h.char, "consumable_healing_potion") == 1, "and no second potion came of it")
        end,
    },
    {
        name = "Quick Brew adds to a carried potion stack rather than spending a cell",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3,
                { isolate = "bare", items = { "ability_quick_brew", "consumable_healing_potion" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            local stack = Fixture.itemNamed(h.char, "consumable_healing_potion")
            local before = stack.quantity or 1
            local cells = 0
            for i = 1, Character.MAX_INVENTORY do if h.char.inventory[i] then cells = cells + 1 end end
            assert(Fixture.strike(combat, h, h, "ability_quick_brew"), "it is brewed")
            assert(stack.quantity == before + 1, "the carried stack grew by one")
            local after = 0
            for i = 1, Character.MAX_INVENTORY do if h.char.inventory[i] then after = after + 1 end end
            assert(after == cells, "and no new cell was spent")
        end,
    },
    {
        name = "Quick Brew on a full grid with no potion stack brews nothing",
        fn = function()
            local map = Fixture.new(10, 10)
            local hero = Fixture.unit("character_ren", 3, 3, { isolate = "bare", items = { "ability_quick_brew" } })
            local foe = Fixture.unit("character_bandit", 9, 9, { isolate = "bare" })
            local combat = Fixture.combat(map, hero, foe)
            local h = combat.units[1]
            h.char.stats.mana.max, h.char.stats.mana.current = 99, 99
            local brew = Fixture.itemNamed(h.char, "ability_quick_brew")
            for i = 1, Character.MAX_INVENTORY do
                if h.char.inventory[i] ~= brew then
                    h.char.inventory[i] = Item.instantiate("weapon_iron_dagger", 1, 0)
                end
            end
            Fixture.strike(combat, h, h, brew)
            assert(countOf(h.char, "consumable_healing_potion") == 0, "nine cells is nine cells")
        end,
    },
}
