-- The fallen stand up at a quarter after a fight the company did not win (models/combat.lua's
-- Combat.standRouted, called from states/game.lua's rout branch -- which a Smoke leaves by too). A body
-- that was DOWN used to walk onto the map at 0 health and into the next fight that way. It is still
-- injured exactly as before; it simply stands. A wipe never calls this. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Injury = require("models.injury")

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

return {
    {
        name = "a body down at the end of a rout stands at a quarter of its usable health, rounded up",
        fn = function()
            local knight, archer = Character.instantiate("character_knight"), Character.instantiate("character_archer")
            local p = Descent.newProfile({ knight, archer })
            local c = Combat.new(arena(8, 8),
                { { char = knight, x = 2, y = 2 }, { char = archer, x = 2, y = 4 } },
                { { char = Character.instantiate("character_bandit"), x = 7, y = 7 } })
            local ku = c.units[1]
            Combat.dealFlatDamage(c, ku, 9999, { "physical" }, "test")
            assert(not ku.alive, "the knight is down")
            assert(knight.stats.health.current <= 0, "and walks off the board at nothing")
            local fallen = Combat.fallenParty(c)
            assert(#fallen == 1 and fallen[1] == knight, "only the knight fell")
            local hurt = Injury.inflict(p, fallen)
            assert(#hurt == 1, "still injured exactly as before")
            local stood = Combat.standRouted(fallen)
            assert(#stood == 1, "the knight is stood up")
            local max = Combat.unreservedMax(knight, "health")
            assert(knight.stats.health.current == math.max(1, math.ceil(max * 0.25)),
                "a quarter of what the injury left, rounded up: " .. knight.stats.health.current .. " of " .. max)
            assert(knight.stats.health.current >= 1, "never below 1")
        end,
    },
    {
        name = "a spent body keeps the sliver it walked off with; only the down are stood",
        fn = function()
            local archer = Character.instantiate("character_archer")
            archer.stats.health.current = 2
            local stood = Combat.standRouted({ archer })
            assert(#stood == 0 and archer.stats.health.current == 2, "a standing body is not topped up")
        end,
    },
    {
        name = "a body that never comes back stays down",
        fn = function()
            local demon = Character.instantiate("character_archer")
            demon.revivable = false
            demon.stats.health.current = 0
            Combat.standRouted({ demon })
            assert(demon.stats.health.current == 0, "revivable = false is honoured, as in victory")
        end,
    },
    {
        name = "a tiny pool still stands at 1",
        fn = function()
            local c = Character.instantiate("character_archer")
            c.stats.health.max, c.stats.health.current = 1, 0
            Combat.standRouted({ c })
            assert(c.stats.health.current == 1, "rounded up, at least 1")
        end,
    },
    {
        name = "the rout branch in states/game.lua stands the fallen after it injures them",
        fn = function()
            local f = assert(io.open("states/game.lua", "rb"))
            local src = f:read("*a"); f:close()
            local rout = src:find('if game.descent and require("states.battle").routed then', 1, true)
            assert(rout, "the rout branch is where it was")
            local inj = src:find("game:inflictInjuries()", rout, true)
            local stand = src:find('Combat.standRouted(require("states.battle").fallen)', rout, true)
            local ret = src:find("return\r?\n", rout)
            assert(inj and stand and inj < stand, "the rout branch injures, then stands")
            assert(ret and stand < ret, "inside the rout branch, before it hands the map back")
        end,
    },
}
