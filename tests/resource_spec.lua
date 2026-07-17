-- Tests for resource management (models/combat.lua + models/status.lua): tick-proportional
-- stamina regen, the generic resource-restore helper, between-battle stamina refill (mana
-- persists), and the item-driven Wait swaps Focus / Defend. Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

-- A flat, all-walkable arena (mirrors tests/combat_spec.lua).
local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

-- A { char, x, y } spawn entry. Accepts a blueprint id or a prebuilt character instance.
local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Find the inventory item with the given id on a character (a party member's new gear).
local function itemNamed(char, id)
    for _, it in ipairs(char.inventory) do
        if it.id == id then return it end
    end
    return nil
end

return {
    {
        name = "stamina regenerates proportional to elapsed ticks; mana does not",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 8, 8) })
            local knight = c.units[1]
            knight.char.stats.stamina.current = 20 -- max 60
            knight.char.stats.mana.current = 5     -- max 20
            -- Knight staminaRegen = 2, so 3 elapsed ticks restore 6.
            Combat.regenerate(c, 3)
            assert(knight.char.stats.stamina.current == 26, "stamina += staminaRegen * elapsed")
            assert(knight.char.stats.mana.current == 5, "mana never regenerates")
        end,
    },
    {
        name = "stamina regen clamps at max",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_archer", 1, 1) }, { unit("character_bandit", 6, 6) })
            local archer = c.units[1]
            archer.char.stats.stamina.current = archer.char.stats.stamina.max - 1
            Combat.regenerate(c, 10) -- archer regen 2 * 10 = 20, but only 1 short of max
            assert(archer.char.stats.stamina.current == archer.char.stats.stamina.max, "clamped to max")
        end,
    },
    {
        name = "restoreResource clamps to max and returns the real delta",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.stats.stamina.current = 55 -- max 60
            assert(Combat.restoreResource(knight, "stamina", 10) == 5, "returns the clamped delta")
            assert(knight.stats.stamina.current == 60, "capped at max")
            assert(Combat.restoreResource(knight, "stamina", 10) == 0, "already full -> 0")
            assert(Combat.restoreResource(knight, "stamina", -3) == 0, "non-positive -> 0")
        end,
    },
    {
        name = "battle start refills stamina but leaves mana (mana persists between battles)",
        fn = function()
            local knight = Character.instantiate("character_knight")
            knight.stats.stamina.current = 10 -- carried-over depletion
            knight.stats.mana.current = 3
            Combat.new(arena(6, 6), { unit(knight, 1, 1) }, { unit("character_bandit", 6, 6) })
            assert(knight.stats.stamina.current == knight.stats.stamina.max, "stamina refilled to max")
            assert(knight.stats.mana.current == 3, "mana persists (not refilled)")
        end,
    },
    {
        name = "Focus wait-behavior restores mana and ends the turn behind the next unit",
        fn = function()
            local priest = Character.instantiate("character_priest")
            priest.stats.mana.current = 10 -- max 70; focus_stone restores 12
            local c = Combat.new(arena(6, 6), { unit(priest, 1, 1) }, { unit("character_bandit", 6, 6) })
            local pu, bandit = c.units[1], c.units[2]
            local focusSpeed = Combat.waitBehavior(pu).speed
            assert(Combat.waitBehavior(pu).kind == "focus", "focus stone swaps Wait -> Focus")
            pu.initiative, bandit.initiative = 0, 5
            openTurn(c, pu)
            assert(Combat.focus(c, pu), "focus succeeds")
            assert(pu.char.stats.mana.current == 22, "mana restored by the focus item's amount")
            -- Focus costs its full speed of the timeline: after rebase (next unit at 5 drops to 0)
            -- the actor trails by focusSpeed - 5, a much bigger delay than a plain wait's +1.
            assert(bandit.initiative == 0, "the next unit rebases to 0")
            assert(pu.initiative == focusSpeed - 5, "actor pushed back by its full focus time cost")
        end,
    },
    {
        name = "Parasitic Staff deals damage and refunds mana to the wielder on hit",
        fn = function()
            local priest = Character.instantiate("character_priest")
            priest.stats.mana.current = 10 -- max 70
            local c = Combat.new(arena(6, 6), { unit(priest, 1, 1) }, { unit("character_bandit", 2, 1) })
            local pu, bandit = c.units[1], c.units[2]
            local staff = itemNamed(pu.char, "weapon_parasitic_staff")
            assert(staff, "priest carries the parasitic staff")
            local staBefore = pu.char.stats.stamina.current
            openTurn(c, pu)
            assert(Combat.useItem(c, pu, staff, bandit.x, bandit.y), "adjacent siphon hits")
            assert(bandit.char.stats.health.current < bandit.char.stats.health.max, "bandit took damage")
            assert(pu.char.stats.mana.current == 15, "wielder regained 5 mana on hit")
            assert(pu.char.stats.stamina.current == staBefore - 6, "stamina cost paid")
        end,
    },
    {
        name = "Defend applies a temporary +defense that expires at the unit's next turn",
        fn = function()
            local archer = Character.instantiate("character_archer")
            local c = Combat.new(arena(6, 6), { unit(archer, 1, 1) }, { unit("character_bandit", 6, 6) })
            local au = c.units[1]
            local brace = Combat.waitBehavior(au)
            assert(brace.kind == "defend", "buckler swaps Wait -> Defend")
            assert(brace.defense == 6, "the buckler's level-0 brace defense (tunable on the shield)")

            -- mitigatedDamage reads the unit's effective defense (flatStat), so it reflects the buff.
            local before = Combat.mitigatedDamage(au, 50, { "physical" })
            openTurn(c, au)
            assert(Combat.defend(c, au), "defend succeeds")
            assert(Status.has(au, "status_defending"), "the Defending status is applied")
            assert(Combat.mitigatedDamage(au, 50, { "physical" }) == before - brace.defense,
                "braced defense matches the shield's tuned amount")

            -- The status self-expires at the start of the unit's next turn.
            Status.onTurnStart(c, au)
            assert(not Status.has(au, "status_defending"), "Defending clears at the next turn start")
            assert(Combat.mitigatedDamage(au, 50, { "physical" }) == before, "defense back to base")
        end,
    },
}
