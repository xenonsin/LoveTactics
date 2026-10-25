-- Smoke (data/items/consumable/consumable_smoke.lua): thrown, it ends a fight that is not a stair and
-- the company slips back onto the map through the rout (states/battle.lua's smokeOut ->
-- states/game.lua's onLoss with `routed` set). Refused on a stair and outside the rift, with the reason on
-- the slot. Standing stock at rung 0, like the draughts.

local Character = require("models.character")
local Combat = require("models.combat")
local Grade = require("models.grade")
local Item = require("models.item")
local Market = require("models.market")

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

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- A two-body board with a Smoke in the hero's grid. `smoke` is what the launcher passed.
local function board(smoke)
    local c = Combat.new(arena(8, 8), { unit("character_rowan", 2, 2) }, { unit("character_bandit", 6, 2) })
    c.smoke = smoke
    local hero, foe = c.units[1], c.units[2]
    hero.char.inventory = { [5] = Item.instantiate("consumable_smoke") }
    hero.char.inventory[5].quantity = 2
    foe.char.inventory = { [5] = Item.instantiate("consumable_smoke") }
    return c, hero, foe
end

local function readText(path)
    local f = assert(io.open(path, "rb"), "cannot read " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

return {
    {
        name = "Smoke is a rung-0 rogue consumable, pinned there, and on the standing rack",
        fn = function()
            local def = assert(Item.defs.consumable_smoke, "consumable_smoke is not a blueprint")
            assert(def.type == "consumable" and def.class == "rogue", "a rogue consumable")
            assert(def.unlockLevel == 0 and def.price == 25, "rung 0, 25 gold")
            assert(def.activeAbility and def.activeAbility.consumesItem, "one Smoke is spent per throw")
            assert(Grade.SLOT_PINS.consumable_smoke and Grade.SLOT_PINS.consumable_smoke.at == 0,
                "pinned at rung 0, so a re-grade cannot gate the way out")
            assert(Market.isStaple(def), "standing stock, like the draughts")
        end,
    },
    {
        name = "thrown in a fight the launcher allows, it marks the fight to end and spends one",
        fn = function()
            local c, hero = board(true)
            assert(Combat.itemBlockReason(hero, hero.char.inventory[5]) == nil, "usable underground")
            c.turn = { unit = hero, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, hero, hero.char.inventory[5], hero.x, hero.y), "the throw lands")
            assert(c.slippedAway == hero, "the fight is marked to end")
            assert(hero.char.inventory[5].quantity == 1, "one Smoke spent (2 -> 1)")
        end,
    },
    {
        name = "a forecast of the throw does not end the fight",
        fn = function()
            local c, hero = board(true)
            Combat.previewAbility(c, hero, hero.char.inventory[5], hero.x, hero.y)
            assert(c.slippedAway == nil, "a hover ended the fight")
        end,
    },
    {
        name = "refused on a stair, outside the rift, and to the far side",
        fn = function()
            local _, hero = board("Not on a stair.")
            local why = Combat.itemBlockReason(hero, hero.char.inventory[5])
            assert(why and why.text == "Not on a stair.", "a stair fight says why: " .. tostring(why and why.text))

            local _, hero2 = board(nil)
            local why2 = Combat.itemBlockReason(hero2, hero2.char.inventory[5])
            assert(why2 and why2.text == "Not in this fight.", "a fight with no map behind it refuses")

            local _, _, foe = board(true)
            assert(Combat.itemBlockReason(foe, foe.char.inventory[5]), "an enemy cannot smoke the company out")
        end,
    },
    {
        name = "the launcher says which fights allow it, and the battle leaves by the rout",
        fn = function()
            -- A SOURCE SCAN of the wiring: the model above can be right with nobody calling it.
            local game = readText("states/game.lua")
            assert(game:find("smoke = game.descent and", 1, true), "states/game.lua passes no `smoke` opt")
            assert(game:find("\"Not on a stair.\"", 1, true), "the stair's refusal is not named")
            local battle = readText("states/battle.lua")
            assert(battle:find("battle.combat.smoke = opts.smoke", 1, true), "the battle does not stamp the opt")
            assert(battle:find("battle.combat.slippedAway and battle.combat.smoke == true", 1, true),
                "resolveAdvance does not end a smoked fight")
            assert(battle:find("battle.routed = true", 1, true) and battle:find("battle.onLoss()", 1, true),
                "smokeOut does not leave through the rout")
        end,
    },
}
