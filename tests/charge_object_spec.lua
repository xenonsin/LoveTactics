-- A charge that runs into FURNITURE (models/combat.lua: Combat.charge, chargeLane). A prop or a wall in
-- the lane has no character sheet, so it cannot be trampled through Combat.dealFlatDamage -- doing so
-- crashed every Gore that ran a body into a crate ("attempt to index field 'char'"). The run stops on
-- the object, and the object takes the collision in its own layer's currency. Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Prop = require("models.prop")

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

return {
    {
        name = "a pinned charge into a crate stops on it and splinters it, no crash",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 2, 4) }, { unit("character_bandit", 3, 4) })
            local knight, bandit = c.units[1], c.units[2]
            local crate = Prop.place(c, 5, 4, "prop_crate")
            local before = crate.health
            local ok, moved = pcall(Combat.charge, c, knight, bandit, 3)
            assert(ok, "the charge must not crash on furniture: " .. tostring(moved))
            assert(moved == 1, "the pair advanced one tile and then met the crate")
            assert(bandit.x == 4, "the target stops against the crate")
            assert(crate.x == 5, "a crate is not shoved aside by a shoulder")
            assert(crate.health < before or not crate.alive, "the crate took the collision")
        end,
    },
    {
        name = "a lane charge (Gore's run) into a crate stops short of it, no crash",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 2, 4) }, { unit("character_bandit", 8, 8) })
            local knight = c.units[1]
            local crate = Prop.place(c, 4, 4, "prop_crate")
            local ok, moved = pcall(Combat.chargeInto, c, knight, 3, 4, 3)
            assert(ok, "the rush must not crash on furniture: " .. tostring(moved))
            assert(moved == 1 and knight.x == 3, "it runs to the crate and stops")
            assert(crate.x == 4 and crate.alive, "the crate stands")
            local tx = Combat.chargeTile(c, knight, 4, 4, 3)
            assert(tx == 3, "the preview agrees: the crate stops the run")
        end,
    },
    {
        name = "a trampling lane charge (Settle's heave) into a crate splinters it, no crash",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 2, 4) }, { unit("character_bandit", 8, 8) })
            local knight = c.units[1]
            local crate = Prop.place(c, 4, 4, "prop_crate")
            local before = crate.health
            local hit = 0
            local ok, err = pcall(Combat.chargeInto, c, knight, 3, 4, 3, {
                lane = true, trample = function(body) hit = hit + 1; Combat.dealFlatDamage(c, body, 5, { "physical" }, "t") end })
            assert(ok, "the heave must not crash on furniture: " .. tostring(err))
            assert(hit == 0, "the caster's blow is for bodies; the crate takes the collision instead")
            assert(crate.health < before or not crate.alive, "the crate took the collision")
        end,
    },
    {
        name = "Combat.dealFlatDamage on a characterless object routes to its own layer",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_rowan", 2, 4) }, { unit("character_bandit", 8, 8) })
            local crate = Prop.place(c, 4, 4, "prop_crate")
            local before = crate.health
            local ok, err = pcall(Combat.dealFlatDamage, c, crate, 3, { "physical", "impact" }, "the charge")
            assert(ok, "the damage funnel never indexes a missing sheet: " .. tostring(err))
            assert(crate.health == before - 3, "the crate lost exactly the blow")
        end,
    },
    {
        name = "Gore run into a crate in a live fight does not crash",
        fn = function()
            local boar = Character.instantiate("character_rowan")
            boar.inventory = {}
            Character.addItem(boar, Item.instantiate("ability_gore"))
            local c = Combat.new(arena(10, 10), { { char = boar, x = 2, y = 4 } }, { unit("character_bandit", 5, 4) })
            local bu = c.units[1]
            Prop.place(c, 3, 4, "prop_crate")
            c.turn = { unit = bu, moved = false, moveCost = 0 }
            local ab = boar.inventory[1]
            local ok, err = pcall(function()
                Combat.useItem(c, bu, ab, 5, 4)
                -- A wind-up resolves on a later beat; release it if the item channels.
                if bu.channel and Combat.resolveChannel then Combat.resolveChannel(c, bu) end
            end)
            assert(ok, "Gore into furniture must not crash: " .. tostring(err))
        end,
    },
}
