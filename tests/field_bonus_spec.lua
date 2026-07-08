-- Tests for positional ("field") bonuses (models/combat.lua): the generic Combat.fieldBonus bag
-- aggregated from terrain tile `bonus` AND placed field objects, and the effective-range it feeds
-- (Combat.abilityRange) through targeting, useItem, attackReach, and the enemy AI. Pure logic,
-- headless. The runtime tile shape carries { type, moveCost, walkable, sightCost, bonus }.

local Character = require("models.character")
local Combat = require("models.combat")

-- Flat all-ground arena; `tweaks` is a list of { x, y, bonus, moveCost } per-tile overrides so a
-- test can drop a range-granting (high-ground) tile onto a specific cell.
local function arena(cols, rows, tweaks)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    for _, t in ipairs(tweaks or {}) do
        local c = tiles[t.y][t.x]
        if t.bonus then c.bonus = t.bonus end
        if t.moveCost then c.moveCost = t.moveCost end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function itemById(char, id)
    for _, it in ipairs(char.inventory) do
        if it.id == id then return it end
    end
end

return {
    {
        name = "fieldBonus aggregates a terrain tile's bonus with any placed field objects",
        fn = function()
            local c = Combat.new(arena(4, 1, { { x = 2, y = 1, bonus = { range = 1 } } }), {}, {})
            assert(Combat.fieldBonus(c, 2, 1).range == 1, "the high-ground tile grants +1 range")
            assert((Combat.fieldBonus(c, 1, 1).range or 0) == 0, "plain ground grants nothing")

            -- A placed field object stacks its bonus on top (the generic future-object seam).
            c.fieldObjects = {
                { x = 3, y = 1, bonus = { range = 2 } },
                { x = 2, y = 1, bonus = { range = 1 } }, -- shares the tile with the terrain bonus
            }
            assert(Combat.fieldBonus(c, 3, 1).range == 2, "a placed object grants its own bonus")
            assert(Combat.fieldBonus(c, 2, 1).range == 2, "object + terrain bonus aggregate (1 + 1)")
        end,
    },
    {
        name = "abilityRange adds the standing tile's range bonus to the ability base",
        fn = function()
            local c = Combat.new(arena(6, 1, { { x = 3, y = 1, bonus = { range = 1 } } }),
                { unit("archer", 3, 1) }, {})
            local u = c.units[1]
            local ab = { range = 3 }
            assert(Combat.abilityRange(c, u, ab) == 4, "on high ground base 3 becomes 4")
            assert(Combat.abilityRange(c, u, ab, 1, 1) == 3, "off it the range is the plain base 3")
            assert(Combat.abilityRange(c, u, { range = nil }) == 1 + 1, "a range-less ability defaults to 1 (+bonus)")
        end,
    },
    {
        name = "standing on high ground lets a ranged attack reach one tile farther",
        fn = function()
            -- Archer's bow is range 3; a foe 4 tiles away is out of reach on open ground...
            local flat = Combat.new(arena(6, 1),
                { unit("archer", 1, 1) }, { unit("bandit", 5, 1) })
            local a = flat.units[1]
            openTurn(flat, a)
            assert(Combat.useItem(flat, a, itemById(a.char, "bow"), 5, 1) == false,
                "range 3 can't hit a foe 4 tiles off on flat ground")

            -- ...but from a +1-range tile the same shot lands.
            local high = Combat.new(arena(6, 1, { { x = 1, y = 1, bonus = { range = 1 } } }),
                { unit("archer", 1, 1) }, { unit("bandit", 5, 1) })
            local ah, foe = high.units[1], high.units[2]
            openTurn(high, ah)
            local hp0 = foe.char.stats.health.current
            assert(Combat.useItem(high, ah, itemById(ah.char, "bow"), 5, 1),
                "high ground extends the bow to reach the 4-tile foe")
            assert(foe.char.stats.health.current < hp0, "the extended shot dealt damage")
        end,
    },
    {
        name = "abilityTargets and attackReach both honour the standing tile's range bonus",
        fn = function()
            -- Fireball is range 3; from a +1 tile the mage can target a foe 4 tiles away.
            local c = Combat.new(arena(8, 1, { { x = 1, y = 1, bonus = { range = 1 } } }),
                { unit("mage", 1, 1) }, { unit("bandit", 5, 1) })
            local mage = c.units[1]
            local targets = Combat.abilityTargets(c, mage, itemById(mage.char, "ability_fireball"))
            assert(#targets == 1 and targets[1] == c.units[2], "the +1 range brings the far foe in range")

            -- attackReach from the same high-ground origin (empty reachable) extends by one tile.
            local ar = Combat.attackReach(c, mage, 3, {}, false)
            assert(ar["5,1"], "reach extends to distance 4 from high ground")
            assert(ar["6,1"] == nil, "but not to distance 5")

            -- On plain ground the same base reach stops a tile shorter.
            local flat = Combat.new(arena(8, 1), { unit("mage", 1, 1) }, {})
            local arFlat = Combat.attackReach(flat, flat.units[1], 3, {}, false)
            assert(arFlat["4,1"] and arFlat["5,1"] == nil, "flat-ground reach is the plain base 3")
        end,
    },
    {
        name = "a placed field object grants the same range buff as terrain (the generic path)",
        fn = function()
            -- Plain arena, no high ground -- the buff comes purely from a placed object on the tile.
            local c = Combat.new(arena(6, 1), { unit("archer", 1, 1) }, { unit("bandit", 5, 1) })
            local a = c.units[1]
            openTurn(c, a)
            assert(Combat.useItem(c, a, itemById(a.char, "bow"), 5, 1) == false,
                "no buff yet: the 4-tile foe is out of range")

            c.fieldObjects = { { x = 1, y = 1, bonus = { range = 1 } } } -- e.g. a vantage totem
            assert(Combat.useItem(c, a, itemById(a.char, "bow"), 5, 1),
                "the placed object's +1 range lets the shot reach, exactly like terrain")
        end,
    },
    {
        name = "the enemy AI uses its high-ground range to strike from farther",
        fn = function()
            local function bowman(x, y)
                local ch = Character.instantiate("archer")
                ch.inventory = { itemById(ch, "bow") } -- strip the trap kit; bow-only plan
                return unit(ch, x, y)
            end

            -- Enemy on a +1 tile, party 4 tiles away: it opens with a shot in place (range 3 -> 4).
            local c = Combat.new(arena(8, 1, { { x = 1, y = 1, bonus = { range = 1 } } }),
                { unit("knight", 5, 1) }, { bowman(1, 1) })
            local plan = Combat.planEnemyAction(c, c.units[2])
            assert(plan.item and not plan.move, "high ground lets it fire without repositioning")
            assert(plan.tx == 5 and plan.ty == 1, "it targets the 4-tile-away knight")
        end,
    },
}
