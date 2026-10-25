-- The knight answers for its party (models/ai.lua's AI.knightGuard). A `defensive` knight used to hold
-- the ring round its post and swing only at what walked into it, so Rowan stood beside the avatar while
-- the company fought three tiles away. Now a foe threatening ANY ally is the knight's fight: it walks at
-- it and strikes it, preferring the foe on the most vulnerable ally. Other defensive bodies -- bosses,
-- mirrors, a slime -- are unchanged. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local AI = require("models.ai")

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

local function dist(a, x, y) return math.abs(a.x - x) + math.abs(a.y - y) end

return {
    {
        name = "Rowan walks off the avatar's ring at a foe threatening another party member",
        fn = function()
            local c = Combat.new(arena(14, 14),
                { unit("character_rowan", 2, 2), unit("character_avatar", 2, 3), unit("character_archer", 7, 8) },
                { unit("character_bandit", 9, 8) })
            local rowan, bandit = c.units[1], c.units[4]
            assert(AI.isKnight(rowan), "Rowan is a knight")
            local guard = AI.knightGuard(c, rowan, AI.post(c, rowan))
            assert(guard and guard.foe == bandit, "the bandit on the archer is the knight's fight")
            local plan = AI.plan(c, rowan)
            assert(plan and plan.move, "she moves: " .. AI.explain(plan))
            assert(dist(bandit, plan.move.x, plan.move.y) < dist(bandit, rowan.x, rowan.y),
                "toward the bandit, not back to her post")
        end,
    },
    {
        name = "within reach of the threat she strikes it, off the post's leash",
        fn = function()
            local c = Combat.new(arena(14, 14),
                -- Two tiles from a stand beside the bandit: a knight in plate walks two (Rowan's reach).
                { unit("character_rowan", 5, 4), unit("character_avatar", 1, 1), unit("character_archer", 8, 5) },
                { unit("character_bandit", 8, 4) })
            local rowan, bandit = c.units[1], c.units[4]
            local plan = AI.plan(c, rowan)
            assert(plan and plan.item and plan.target == bandit, "she swings at the bandit: " .. AI.explain(plan))
        end,
    },
    {
        name = "with nothing threatening anybody, the knight still holds its post",
        fn = function()
            local c = Combat.new(arena(20, 20),
                { unit("character_rowan", 2, 2), unit("character_avatar", 2, 3) },
                { unit("character_bandit", 19, 19) })
            local rowan = c.units[1]
            assert(AI.knightGuard(c, rowan, AI.post(c, rowan)) == nil, "no foe is near anybody")
            local plan = AI.plan(c, rowan)
            assert(not plan.move and not plan.item, "she holds: " .. AI.explain(plan))
        end,
    },
    {
        name = "between two threats it prefers the foe on the most vulnerable ally",
        fn = function()
            local c = Combat.new(arena(14, 14),
                { unit("character_rowan", 6, 6), unit("character_archer", 4, 4), unit("character_priest", 8, 8),
                  unit("character_avatar", 1, 13) },
                { unit("character_bandit", 4, 5), unit("character_bandit", 8, 9) })
            local rowan, archer, priest = c.units[1], c.units[2], c.units[3]
            local onArcher, onPriest = c.units[5], c.units[6]
            local hp = priest.char.stats.health
            hp.current = math.max(1, math.floor(hp.max * 0.3))
            local guard = AI.knightGuard(c, rowan, AI.post(c, rowan))
            assert(guard and guard.ward == priest, "the wounded priest is the most vulnerable")
            assert(guard.foe == onPriest, "and the bandit on her is the knight's mark")
            assert(guard.threats[onArcher], "the other bandit is still a threat")
            assert(AI.guardBonus({ guard = guard }, { target = onPriest })
                > AI.guardBonus({ guard = guard }, { target = onArcher }), "the mark outranks the other threat")
            local _ = archer
        end,
    },
    {
        name = "a defensive body that is not a knight is unchanged",
        fn = function()
            local champ = Character.instantiate("character_champion")
            assert(champ.archetype == "defensive" and champ.class ~= "knight", "the champion is a defensive fighter")
            local c = Combat.new(arena(14, 14),
                { { char = champ, x = 2, y = 2 }, unit("character_avatar", 2, 3), unit("character_archer", 7, 8) },
                { unit("character_bandit", 9, 8) })
            local plan = AI.plan(c, c.units[1])
            assert(not plan.move and not plan.item, "it holds as it always did: " .. AI.explain(plan))
        end,
    },
    {
        name = "a knight holding objective ground stays on it",
        fn = function()
            local c = Combat.new(arena(14, 14),
                { unit("character_rowan", 2, 2), unit("character_archer", 7, 8) },
                { unit("character_bandit", 9, 8) })
            assert(AI.knightGuard(c, c.units[1], { tiles = { { x = 2, y = 2 } }, radius = 0, what = "the objective" })
                == nil, "ground held by standing on it is what it defends")
        end,
    },
}
