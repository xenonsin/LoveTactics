-- Tests for the battle board's FACING (ui/battle_map.lua's rotation section): Settings'
-- "Party at the bottom", and the two turn plates in the fight's drawer.
--
-- All of it is arithmetic over a grid and a pixel origin, so it runs headless -- but only on a map
-- built the awkward way, since BattleMap.new wants a tileset and a font. The stand-in below is given
-- the real metatable and then laid out by the real layout(), so every function under test here is the
-- one the game runs; nothing about the turn is reimplemented in this file.
--
-- The invariant that matters is the one the feature is FOR: a fight entered from the north must, with
-- the preference on, put the player's own ground on the near side of the screen. That is the last case.

local BattleMap = require("ui.battle_map")
local Scale = require("scale")

local TILE = 60 -- states/battle.lua BOARD_TILE

-- A board `cols` x `rows`, facing `rotation`, laid out in the same column margins the fight uses.
local function board(cols, rows, rotation)
    local map = setmetatable({
        arena = { cols = cols, rows = rows },
        size = TILE,
        leftMargin = 264,  -- LEFT_W
        rightMargin = 320, -- PANEL_W
        topMargin = 104,   -- BOARD_TOP
        rotation = (rotation or 0) % 4,
    }, BattleMap)
    map:layout()
    return map
end

local function eachCell(map, fn)
    for y = 1, map.arena.rows do
        for x = 1, map.arena.cols do fn(x, y) end
    end
end

return {
    {
        name = "every facing round-trips a cell through pixels and back",
        fn = function()
            for r = 0, 3 do
                local map = board(8, 8, r)
                eachCell(map, function(x, y)
                    local px, py = map:cellToPixel(x, y)
                    -- Sample the middle of the tile: a corner is shared with its neighbours.
                    local bx, by = map:pixelToCell(px + TILE / 2, py + TILE / 2)
                    assert(bx == x and by == y,
                        ("facing %d lost the cell %d,%d (came back %s,%s)"):format(r, x, y, bx, by))
                end)
            end
        end,
    },
    {
        name = "a facing rearranges the board without moving it, losing or doubling a tile",
        fn = function()
            for r = 0, 3 do
                local map = board(8, 8, r)
                local bx, by, bw, bh = map:boardRect()
                local seen, n = {}, 0
                eachCell(map, function(x, y)
                    local px, py = map:cellToPixel(x, y)
                    local key = px .. "," .. py
                    assert(not seen[key], ("facing %d put two tiles on %s"):format(r, key))
                    seen[key] = true
                    n = n + 1
                    assert(px >= bx and py >= by and px + TILE <= bx + bw and py + TILE <= by + bh,
                        ("facing %d put cell %d,%d outside the board's own rect"):format(r, x, y))
                end)
                assert(n == 64, "the board lost tiles under a turn")
            end
        end,
    },
    {
        name = "a board that is not square lies the other way round on its side",
        fn = function()
            local flat = board(10, 6, 0)
            local _, _, w, h = flat:boardRect()
            assert(w == 10 * TILE and h == 6 * TILE, "an unturned board is not its own size")

            local onEnd = board(10, 6, 1)
            local _, _, w2, h2 = onEnd:boardRect()
            assert(w2 == 6 * TILE and h2 == 10 * TILE, "a quarter turn did not swap the board's extent")
            -- ...and it is still centred between the two columns, not left hanging where it was.
            local bx = onEnd:boardRect()
            assert(bx > 264, "a turned board slid under the left column")
            assert(bx + w2 < Scale.WIDTH - 320, "a turned board slid under the combat panel")
        end,
    },
    {
        name = "a step on the keyboard goes where the player is looking, not where the grid points",
        fn = function()
            -- Pushing DOWN must always move the cursor toward the bottom of the SCREEN, whichever way
            -- the board is facing -- that is the whole reason moveCursor turns its deltas.
            for r = 0, 3 do
                local map = board(8, 8, r)
                map.cursor = { x = 4, y = 4 }
                local _, before = map:cellToPixel(map.cursor.x, map.cursor.y)
                map:moveCursor(0, 1)
                local _, after = map:cellToPixel(map.cursor.x, map.cursor.y)
                assert(after == before + TILE, ("facing %d: 'down' did not go down"):format(r))

                local rightBefore = map:cellToPixel(map.cursor.x, map.cursor.y)
                map:moveCursor(1, 0)
                local rightAfter = map:cellToPixel(map.cursor.x, map.cursor.y)
                assert(rightAfter == rightBefore + TILE, ("facing %d: 'right' did not go right"):format(r))
            end
        end,
    },
    {
        name = "a body wider than it is deep lies across the screen once the board is turned",
        fn = function()
            local flat = board(8, 8, 0)
            local _, _, bw, bh = flat:cellBox(3, 3, 2, 1)
            assert(bw == 2 * TILE and bh == TILE, "an unturned 2x1 body is not 2x1")

            local turned = board(8, 8, 1)
            local ox, oy, tw, th = turned:cellBox(3, 3, 2, 1)
            assert(tw == TILE and th == 2 * TILE, "a turned 2x1 body did not stand up")
            -- The anchor cell is the box's top-RIGHT corner at this facing, so the box must reach back
            -- over BOTH cells rather than hanging off the one the model names.
            local ax, ay = turned:cellToPixel(3, 3)
            local bx2, by2 = turned:cellToPixel(4, 3)
            assert(ox <= math.min(ax, bx2) and oy <= math.min(ay, by2),
                "the body's box left one of its own cells outside it")
            assert(ox + tw >= math.max(ax, bx2) + TILE and oy + th >= math.max(ay, by2) + TILE,
                "the body's box stopped short of one of its own cells")
        end,
    },
    {
        name = "an arrival's edge is named as the screen sees it",
        fn = function()
            local map = board(8, 8, 1) -- a quarter turn clockwise
            assert(map:screenEdge("top") == "right", "the grid's top did not swing to the right")
            assert(map:screenEdge("right") == "bottom", "the grid's right did not swing to the bottom")
            assert(map:screenEdge("bottom") == "left", "the grid's bottom did not swing to the left")
            assert(map:screenEdge("left") == "top", "the grid's left did not swing to the top")
            assert(board(8, 8, 0):screenEdge("top") == "top", "an unturned board renamed an edge")
        end,
    },
    {
        name = "party at the bottom: whichever edge the company enters on ends up the near one",
        fn = function()
            -- One case per entry edge, each a two-deep band along that edge -- exactly the shape
            -- models/arena.lua cuts a deploy zone in (bandTiles on the entry edge, DEPLOY_DEPTH 2).
            local zones = {
                top    = { { x = 3, y = 1 }, { x = 4, y = 1 }, { x = 3, y = 2 }, { x = 4, y = 2 } },
                bottom = { { x = 3, y = 8 }, { x = 4, y = 8 }, { x = 3, y = 7 }, { x = 4, y = 7 } },
                left   = { { x = 1, y = 3 }, { x = 1, y = 4 }, { x = 2, y = 3 }, { x = 2, y = 4 } },
                right  = { { x = 8, y = 3 }, { x = 8, y = 4 }, { x = 7, y = 3 }, { x = 7, y = 4 } },
            }
            for edge, zone in pairs(zones) do
                local map = board(8, 8, BattleMap.rotationForBottom(edge))
                local _, by, _, bh = map:boardRect()
                local middle = by + bh / 2
                for _, t in ipairs(zone) do
                    local _, py = map:cellToPixel(t.x, t.y)
                    assert(py >= middle,
                        ("entering from the %s left the company's ground on the far half"):format(edge))
                end
            end
        end,
    },
}
