-- Tests for the board's status badge row (ui/battle_map.lua statusBadgeRects). The row is pure
-- geometry, so it runs headless; the badges' drawing is covered by the in-game verification pass.
-- What matters here is containment: the row is right-justified inside a 60px tile, and a unit
-- carrying more statuses than fit must NOT push badges out past the tile's left edge.

local BattleMap = require("ui.battle_map")

local TILE = 60 -- states/battle.lua BOARD_TILE

-- A stand-in for a real map: statusBadgeRects only reads self.size.
local function rects(n, wx, wy)
    local statuses = {}
    for i = 1, n do statuses[i] = { name = "s" .. i, def = { abbr = "Ab" .. i } } end
    return BattleMap.statusBadgeRects({ size = TILE }, { statuses = statuses }, wx or 0, wy or 0)
end

local function bounds(rs)
    local lo, hi = math.huge, -math.huge
    for _, r in ipairs(rs) do
        lo, hi = math.min(lo, r.x), math.max(hi, r.x + r.w)
    end
    return lo, hi
end

return {
    {
        name = "a unit with no statuses gets no badges",
        fn = function()
            assert(#rects(0) == 0, "empty status list should produce no rects")
        end,
    },
    {
        name = "every badge row stays inside its tile",
        fn = function()
            for n = 1, 8 do
                local rs = rects(n, 100, 100)
                local lo, hi = bounds(rs)
                assert(lo >= 100, n .. " badges spill past the tile's left edge (x=" .. lo .. ")")
                assert(hi <= 100 + TILE, n .. " badges spill past the tile's right edge")
                for _, r in ipairs(rs) do
                    assert(r.y >= 100 and r.y + r.h <= 100 + TILE, n .. " badges spill vertically")
                end
            end
        end,
    },
    {
        name = "a row that fits shows every status and no overflow marker",
        fn = function()
            for n = 1, 4 do
                local rs = rects(n)
                assert(#rs == n, n .. " statuses should get " .. n .. " badges, got " .. #rs)
                for _, r in ipairs(rs) do
                    assert(r.st, "a fitting row should carry only statuses")
                end
            end
        end,
    },
    {
        name = "a row that overflows ends in a +n marker covering the rest",
        fn = function()
            local rs = rects(7)
            local last = rs[#rs]
            assert(last.more, "an overflowing row's last badge should be the +n marker")
            assert(not last.st, "the +n marker is not a status (statusAt must not tooltip it)")
            local shown = #rs - 1
            assert(last.more == 7 - shown,
                "+n should count the hidden statuses: expected " .. (7 - shown) .. ", got " .. last.more)
        end,
    },
    {
        name = "badges are right-justified and never overlap",
        fn = function()
            for n = 1, 8 do
                local rs = rects(n, 100, 100)
                local _, hi = bounds(rs)
                assert(hi == 100 + TILE - 4, "row " .. n .. " should end at the tile's right inset")
                for i = 2, #rs do
                    assert(rs[i].x >= rs[i - 1].x + rs[i - 1].w, "badges overlap at " .. n)
                end
            end
        end,
    },
}
