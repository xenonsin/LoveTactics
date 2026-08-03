-- Tests for models/curve.lua -- the per-level curve generators blueprints use instead of hand-typing
-- eleven integers. Headless.
--
-- The migration's real safety net is the golden snapshot (tools/curve_migrate.lua compares every
-- item's every magnitude at every level, before and after, and expects no difference at all). These
-- cases cover the generator itself: its shape, its endpoints, and the properties a blueprint author
-- is entitled to rely on when reaching for it.

local Curve = require("models.curve")
local Item = require("models.item")

local function same(got, want)
    if #got ~= #want then return false, "got " .. #got .. " entries, expected " .. #want end
    for i = 1, #want do
        if got[i] ~= want[i] then
            return false, "entry " .. i .. " (level " .. (i - 1) .. ") is " .. tostring(got[i])
                .. ", expected " .. tostring(want[i]) .. " -- got { " .. table.concat(got, ", ") .. " }"
        end
    end
    return true
end

return {
    {
        name = "a ramp is a straight line from base to top, one entry per forge level",
        fn = function()
            local ok, why = same(Curve.ramp(8, 18), { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 })
            assert(ok, "chainmail's defense curve: " .. tostring(why))
            local sword, why2 = same(Curve.ramp(6, 16), { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 })
            assert(sword, "the iron sword's damage curve: " .. tostring(why2))
        end,
    },
    {
        -- Not a rounding accident: a good third of the game's curves were authored to hold for a
        -- level and then step by two, because a chunkier step reads better on the forge ladder.
        name = "a paired curve climbs the same line in pairs of levels, and lands on the same top",
        fn = function()
            local ok, why = same(Curve.paired(3, 8), { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 })
            assert(ok, "chainmail's slash resist: " .. tostring(why))
            local ok2, why2 = same(Curve.paired(18, 28), { 18, 18, 20, 20, 22, 22, 24, 24, 26, 26, 28 })
            assert(ok2, "the wildcraft reagent's healing: " .. tostring(why2))
        end,
    },
    {
        name = "both styles span exactly LEVELS entries and honour both endpoints",
        fn = function()
            for _, style in ipairs({ "ramp", "paired" }) do
                for _, pair in ipairs({ { 4, 9 }, { 12, 24 }, { 24, 50 }, { 1, 1 }, { 0, 0 } }) do
                    local c = Curve[style](pair[1], pair[2])
                    assert(#c == Curve.LEVELS, style .. " returned " .. #c .. " entries, expected "
                        .. Curve.LEVELS)
                    assert(c[1] == pair[1], style .. " must start at its base, got " .. c[1])
                    assert(c[Curve.LEVELS] == pair[2], style .. " must finish at its top, got "
                        .. c[Curve.LEVELS])
                end
            end
        end,
    },
    {
        -- The single-argument form is the one most blueprints want, so it had better mean the shape
        -- most of them use.
        name = "a curve with no top doubles by the last forge level",
        fn = function()
            local c = Curve.ramp(8)
            assert(c[1] == 8 and c[Curve.LEVELS] == 16,
                "ramp(8) should run 8..16, got " .. c[1] .. ".." .. c[Curve.LEVELS])
            local ok = same(Curve.ramp(8), Curve.ramp(8, 16))
            assert(ok, "the one-argument form must equal spelling the doubled top out")
        end,
    },
    {
        -- Lua's floor(x + 0.5) rounds half UP, not half away from zero, so without care a curve
        -- authored as a discount would bend differently from the identical curve authored as a gain.
        -- A blueprint should not have to know which side of zero it is on.
        name = "a descending curve is the exact mirror of the ascending one",
        fn = function()
            for _, style in ipairs({ "ramp", "paired" }) do
                local up = Curve[style](1, 4)
                local down = Curve[style](-1, -4)
                for i = 1, Curve.LEVELS do
                    assert(down[i] == -up[i], style .. " is asymmetric at level " .. (i - 1)
                        .. ": " .. down[i] .. " is not the negation of " .. up[i])
                end
            end
        end,
    },
    {
        name = "a curve never doubles back on itself",
        fn = function()
            for _, style in ipairs({ "ramp", "paired" }) do
                local up = Curve[style](5, 12)
                local down = Curve[style](-1, -4)
                for i = 2, Curve.LEVELS do
                    assert(up[i] >= up[i - 1], style .. " dips at level " .. (i - 1))
                    assert(down[i] <= down[i - 1], "a descending " .. style .. " rises at level "
                        .. (i - 1))
                end
            end
        end,
    },
    {
        -- The reason the generators return a plain list rather than a closure or a lazy object:
        -- everything downstream (Item.resolveLevel, eachMagnitude, Item.growth, and
        -- tests/item_contract_spec.lua's per-level row sweep) reads a real indexable table.
        name = "a generated curve is an ordinary list a blueprint could have typed by hand",
        fn = function()
            local c = Curve.ramp(6, 16)
            assert(type(c) == "table" and #c == Curve.LEVELS, "a curve is a plain list")
            for i = 1, #c do assert(type(c[i]) == "number", "entry " .. i .. " is not a number") end
            assert(Item.resolveLevel(c, 0) == 6, "resolveLevel reads level 0 off it")
            assert(Item.resolveLevel(c, 3) == 9, "resolveLevel reads level 3 off it")
            assert(Item.resolveLevel(c, Item.MAX_LEVEL) == 16, "and the top level")
        end,
    },
    {
        name = "the forge ceiling is derived from the curve length, not written out twice",
        fn = function()
            assert(Item.MAX_LEVEL == Curve.LEVELS - 1,
                "Item.MAX_LEVEL (" .. Item.MAX_LEVEL .. ") must be Curve.LEVELS - 1 ("
                .. (Curve.LEVELS - 1) .. ") -- a curve that stopped short of the ceiling would"
                .. " silently repeat its last entry forever")
        end,
    },
}
