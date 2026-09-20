-- Tests for positional ("field") bonuses (models/combat.lua): the generic Combat.fieldBonus bag
-- aggregated from terrain tile `bonus` AND placed field objects, and the effective-range it feeds
-- (Combat.abilityRange) through targeting, useItem, attackReach, and the enemy AI. Pure logic,
-- headless. The runtime tile shape carries { type, moveCost, walkable, sightCost, bonus }.

local Character = require("models.character")
local Combat = require("models.combat")
local Terrain = require("models.terrain")
local TileTooltip = require("ui.tile_tooltip")

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
        name = "abilityRange adds the standing tile's range bonus to a SIGHTED ability's base",
        fn = function()
            local c = Combat.new(arena(6, 1, { { x = 3, y = 1, bonus = { range = 1 } } }),
                { unit("character_archer", 3, 1) }, {})
            local u = c.units[1]
            local ab = { range = 3, requiresSight = true }
            assert(Combat.abilityRange(c, u, ab) == 4, "on high ground base 3 becomes 4")
            assert(Combat.abilityRange(c, u, ab, 1, 1) == 3, "off it the range is the plain base 3")
            assert(Combat.abilityRange(c, u, { range = nil, requiresSight = true }) == 1 + 1,
                "a range-less sighted ability defaults to 1 (+bonus)")
        end,
    },
    {
        -- The bug this gate exists for: a range-1 sword swung from a hill reached two tiles and
        -- struck a foe standing on the far side of an ally. High ground is a sightline, not a longer arm.
        name = "high ground does NOT lengthen a melee swing (no sight, no vantage)",
        fn = function()
            local high = { { x = 3, y = 1, bonus = { range = 1 } } }
            local c = Combat.new(arena(6, 1, high), { unit("character_archer", 3, 1) }, {})
            local u = c.units[1]
            assert(Combat.abilityRange(c, u, { range = 1 }) == 1, "a melee ability keeps its own reach")
            assert(Combat.abilityRange(c, u, { range = 2 }) == 2, "so does a reach weapon (a spear)")

            -- ...and the reach overlay agrees, so the highlight can't promise a swing the gate refuses.
            local ar = Combat.attackReach(c, u, 1, {}, false)
            assert(ar["2,1"] and ar["1,1"] == nil, "melee reach from high ground is still one tile")

            -- The whole board case: sword-wielder on the hill, ally between, foe two tiles off.
            local board = Combat.new(arena(6, 1, { { x = 3, y = 1, bonus = { range = 1 } } }),
                { unit("character_rowan", 3, 1), unit("character_rowan", 2, 1) },
                { unit("character_bandit", 1, 1) })
            local k, foe = board.units[1], board.units[3]
            local sword = itemById(k.char, "weapon_iron_sword") or Combat.defaultAction(k.char)
            openTurn(board, k)
            local hp0 = foe.char.stats.health.current
            assert(Combat.useItem(board, k, sword, foe.x, foe.y) == false,
                "the swing is refused: the foe is two tiles off, behind an ally")
            assert(foe.char.stats.health.current == hp0, "and nothing was dealt")
        end,
    },
    {
        name = "standing on high ground lets a ranged attack reach one tile farther",
        fn = function()
            -- Archer's bow is range 3; a foe 4 tiles away is out of reach on open ground...
            local flat = Combat.new(arena(6, 1),
                { unit("character_archer", 1, 1) }, { unit("character_bandit", 5, 1) })
            local a = flat.units[1]
            openTurn(flat, a)
            assert(Combat.useItem(flat, a, itemById(a.char, "weapon_iron_bow"), 5, 1) == false,
                "range 3 can't hit a foe 4 tiles off on flat ground")

            -- ...but from a +1-range tile the same shot lands.
            local high = Combat.new(arena(6, 1, { { x = 1, y = 1, bonus = { range = 1 } } }),
                { unit("character_archer", 1, 1) }, { unit("character_bandit", 5, 1) })
            local ah, foe = high.units[1], high.units[2]
            openTurn(high, ah)
            local hp0 = foe.char.stats.health.current
            assert(Combat.useItem(high, ah, itemById(ah.char, "weapon_iron_bow"), 5, 1),
                "high ground extends the bow to reach the 4-tile foe")
            assert(foe.char.stats.health.current < hp0, "the extended shot dealt damage")
        end,
    },
    {
        name = "abilityTargets and attackReach both honour the standing tile's range bonus",
        fn = function()
            -- Fireball is range 3; from a +1 tile the mage can target a foe 4 tiles away.
            local c = Combat.new(arena(8, 1, { { x = 1, y = 1, bonus = { range = 1 } } }),
                { unit("character_mage", 1, 1) }, { unit("character_bandit", 5, 1) })
            local mage = c.units[1]
            local targets = Combat.abilityTargets(c, mage, itemById(mage.char, "ability_fireball"))
            assert(#targets == 1 and targets[1] == c.units[2], "the +1 range brings the far foe in range")

            -- attackReach from the same high-ground origin (empty reachable) extends by one tile.
            -- requiresSight = true both traces the line AND claims the vantage (fireball is a shot).
            local ar = Combat.attackReach(c, mage, 3, {}, true)
            assert(ar["5,1"], "reach extends to distance 4 from high ground")
            assert(ar["6,1"] == nil, "but not to distance 5")

            -- On plain ground the same base reach stops a tile shorter.
            local flat = Combat.new(arena(8, 1), { unit("character_mage", 1, 1) }, {})
            local arFlat = Combat.attackReach(flat, flat.units[1], 3, {}, true)
            assert(arFlat["4,1"] and arFlat["5,1"] == nil, "flat-ground reach is the plain base 3")
        end,
    },
    {
        name = "a placed field object grants the same range buff as terrain (the generic path)",
        fn = function()
            -- Plain arena, no high ground -- the buff comes purely from a placed object on the tile.
            local c = Combat.new(arena(6, 1), { unit("character_archer", 1, 1) }, { unit("character_bandit", 5, 1) })
            local a = c.units[1]
            openTurn(c, a)
            assert(Combat.useItem(c, a, itemById(a.char, "weapon_iron_bow"), 5, 1) == false,
                "no buff yet: the 4-tile foe is out of range")

            c.fieldObjects = { { x = 1, y = 1, bonus = { range = 1 } } } -- e.g. a vantage totem
            assert(Combat.useItem(c, a, itemById(a.char, "weapon_iron_bow"), 5, 1),
                "the placed object's +1 range lets the shot reach, exactly like terrain")
        end,
    },
    {
        name = "the enemy AI uses its high-ground range to strike from farther",
        fn = function()
            local function bowman(x, y)
                local ch = Character.instantiate("character_archer")
                ch.inventory = { itemById(ch, "weapon_iron_bow") } -- strip the trap kit; bow-only plan
                return unit(ch, x, y)
            end

            -- Enemy on a +1 tile, party 4 tiles away: it opens with a shot in place (range 3 -> 4).
            -- The knight's move+reach covers this whole 8x1 corridor, so the bowman is threatened
            -- wherever it stands and holds its ground on STANDOFF rather than on EXPOSURE -- see
            -- AI.riskScore, and tests/ai_spec.lua for that term on its own.
            local c = Combat.new(arena(8, 1, { { x = 1, y = 1, bonus = { range = 1 } } }),
                { unit("character_rowan", 5, 1) }, { bowman(1, 1) })
            local plan = Combat.planEnemyAction(c, c.units[2])
            assert(plan.item and not plan.move, "high ground lets it fire without repositioning")
            assert(plan.tx == 5 and plan.ty == 1, "it targets the 4-tile-away knight")
        end,
    },

    -- -----------------------------------------------------------------------
    -- WHAT A TILE IS ALLOWED TO PROMISE
    -- -----------------------------------------------------------------------
    --
    -- The bag takes any key and, for most of this file's life, exactly TWO of them were ever read --
    -- while ui/tile_tooltip.lua carried its own list of SEVEN and printed whatever was non-zero. A tile
    -- authored `bonus = { defense = 2 }` therefore displayed "+2 Defense bonus" to the player and moved
    -- no number in the fight. Nothing had gone wrong only because nothing authored those keys, which is
    -- the definition of a fault waiting for its first author. These three close it from every side.
    {
        name = "every bonus a terrain tile authors is a key something actually reads",
        fn = function()
            local bad = {}
            for name, def in pairs(Terrain.TYPES) do
                for key in pairs(def.bonus or {}) do
                    if not Terrain.readsBonus(key) then
                        bad[#bad + 1] = name .. "." .. key
                    end
                end
            end
            table.sort(bad)
            assert(#bad == 0, "tiles promise bonuses no read site honours: " .. table.concat(bad, ", "))
        end,
    },
    {
        name = "every declared bonus key has a word for the player and a named read site",
        fn = function()
            assert(#Terrain.BONUS_KEYS > 0, "the declaration cannot be empty")
            for _, entry in ipairs(Terrain.BONUS_KEYS) do
                assert(entry.read and entry.read ~= "",
                    entry.key .. " is declared legal without naming what reads it")
                -- ...and the other direction. A key with no label falls through to titleCase and the
                -- player is shown a FIELD NAME -- "Avoid bonus" where the row should read "Cover
                -- (harder to hit)". The tooltip owns the words; this is what stops it losing one.
                assert(TileTooltip.BONUS_LABEL[entry.key],
                    entry.key .. " has no label in ui/tile_tooltip.lua, so the tile would name the "
                    .. "field rather than describe it")
            end
        end,
    },
    {
        name = "the tooltip prints a declared bonus, and prints it in the terrain table's order",
        fn = function()
            -- The fort is the one tile carrying two of them at once, which makes it the only case
            -- that can see an ordering bug at all.
            local cell = { type = "fort", walkable = true, moveCost = 2, sightCost = 0 }
            local blocks = TileTooltip.blocks({ cell = cell, bonus = { avoid = 10, defense = 1 } })
            local seen = {}
            for _, b in ipairs(blocks) do
                if b.kind == "stat" and b.label == TileTooltip.BONUS_LABEL.avoid then
                    seen[#seen + 1] = "avoid"
                    assert(b.value == "+10%", "cover is quoted as a percentage, saw " .. tostring(b.value))
                elseif b.kind == "stat" and b.label == TileTooltip.BONUS_LABEL.defense then
                    seen[#seen + 1] = "defense"
                    assert(b.value == "+1", "armour is a plain point, saw " .. tostring(b.value))
                end
            end
            assert(#seen == 2, "the box should show both of the fort's bonuses, saw " .. #seen)
            assert(seen[1] == "avoid" and seen[2] == "defense",
                "cover leads, as Terrain.BONUS_KEYS orders it")
        end,
    },

    -- -----------------------------------------------------------------------
    -- THE GROUND REACHING A STAT, AND THE BODY THAT IS NOT ON IT
    -- -----------------------------------------------------------------------
    {
        name = "a tile's defence bonus reaches flatStat through the arrival stamp",
        fn = function()
            local c = Combat.new(arena(4, 1, { { x = 3, y = 1, bonus = { defense = 1 } } }),
                { unit("character_rowan", 1, 1) }, {})
            local u = c.units[1]
            local open = Combat.flatStat(u, "defense")

            -- Walking onto the tile re-banks the ground (Combat.enterTile -> stampField), so the very
            -- next read of the stat carries it. Moved by hand rather than by a route so the case is
            -- about the stamp and not about the walk.
            u.x, u.y = 3, 1
            Combat.enterTile(c, u, 3, 1, "walk", 1, 1)
            assert(Combat.flatStat(u, "defense") == open + 1,
                "standing on the work should thicken the armour by its one point")

            -- ...and stepping off gives it back. A stamp that only ever added would be worse than no
            -- stamp at all: the number would be right once and wrong forever after.
            u.x, u.y = 1, 1
            Combat.enterTile(c, u, 1, 1, "walk", 3, 1)
            assert(Combat.flatStat(u, "defense") == open,
                "open ground gives nothing back, and takes the parapet with it")
        end,
    },
    {
        name = "a flier takes nothing from the ground, and everything from a placed object",
        fn = function()
            local c = Combat.new(arena(4, 1, {
                { x = 2, y = 1, bonus = { avoid = 20, range = 1, defense = 1 } },
            }), { unit("character_rowan", 2, 1) }, {})
            local u = c.units[1]

            -- On foot: the tile answers for all three.
            assert(Combat.fieldBonus(c, 2, 1, u).avoid == 20, "a walking body is IN the wood")
            assert(Combat.terrainAvoid(c, 2, 1, u) == 20, "...and its avoid reads the same")

            -- Airborne. Nothing here fakes the tag: Combat.isFlying scans the grid, so the case puts a
            -- real flying item in it, which is the same thing the Zephyr Striders do.
            u.char.inventory[#u.char.inventory + 1] = { id = "__spec_wings", name = "Spec Wings",
                                                        tags = { "flying" } }
            assert(Combat.isFlying(u), "the fixture has to actually fly for this case to mean anything")
            assert((Combat.fieldBonus(c, 2, 1, u).avoid or 0) == 0,
                "a body over the wood is not in it")
            assert((Combat.fieldBonus(c, 2, 1, u).range or 0) == 0,
                "...and gets no vantage from a rise it never climbed")
            assert(Combat.terrainAvoid(c, 2, 1, u) == 0, "the avoid read agrees with the bag")

            -- The tile still answers for anybody ELSE, and for a caller describing bare ground.
            assert(Combat.fieldBonus(c, 2, 1).avoid == 20,
                "asked about the ground rather than a body, the tile is still a wood")

            -- A placed object is at the body's own altitude, so it survives the rule. Without this the
            -- flier clause would quietly gut every future zone that grants a positional buff.
            c.fieldObjects = { { x = 2, y = 1, bonus = { range = 2 } } }
            assert(Combat.fieldBonus(c, 2, 1, u).range == 2,
                "a vantage object reaches a flier; the undergrowth does not")
        end,
    },
}
