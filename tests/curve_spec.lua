-- Tests for models/curve.lua -- the per-level curve generator blueprints use instead of hand-typing
-- eleven integers, and the span rule that makes a forge level worth paying for. Headless.
--
-- The rule, in one sentence: a magnitude either climbs at least a point per forge level, or it is not a
-- curve at all. A curve that climbs less far than it has levels MUST hold somewhere, and a level where
-- nothing moves is one the vendor still charges 60 gold for (models/vendor.lua's upgradeCost bills by
-- target level, not by gain) -- the ladder printed "8, 8" and the player paid for it. So the last case
-- here sweeps every tuned magnitude in the game and insists that each one either moves at every level
-- or does not pretend to.

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

-- The containers models/item.lua's eachMagnitude walks, so the sweep below sees every tuned row.
local CONTAINERS = { "activeAbility", "bonus", "resist", "maxBonus", "unarmedBonus", "waitBehavior",
                     "incense", "aura", "traitParams" }

-- The magnitudes counted in WHOLE STEPS, where a point per level is not a stronger item but a broken
-- one: a ward that swallows eleven blows, a boot granting eleven tiles of movement, a spell reaching
-- eleven tiles further, a tempo discount of -10. Each is the only growth its item has, so flattening it
-- would leave nothing to forge at all -- they keep their authored step curve, spelled out as a literal
-- list so the exception is visible where it lives. Anything NOT on this list has to obey the rule.
local STEP_CURVES = {
    ability_magical_barrier = { ["activeAbility.hits"] = true },
    ability_physical_barrier = { ["activeAbility.hits"] = true },
    utility_boots_of_speed = { ["bonus.movement"] = true },
    utility_sidelong_greaves = { ["bonus.movement"] = true },
    utility_vanishing_act = { ["bonus.movement"] = true },
    utility_wolfsong_horn = { ["bonus.speed"] = true },
    utility_distant_sigil = { ["aura.rangeBonus"] = true },
    utility_long_fuse_reagent = { ["aura.rangeBonus"] = true },
    utility_quickened_sigil = { ["aura.speedBonus"] = true },
    utility_shadow_fist = { ["unarmedBonus.range"] = true },
    utility_swift_fist = { ["unarmedBonus.hits"] = true },
    -- Battle Casting's refund is paid per BODY a blow lands on, so a cleave collects it three times in
    -- one swing: ramp(3, 13) would hand an axe 39 mana a turn and make the sword the spell budget
    -- rather than the reason for one. Its Spell Discount, on the same item, is an ordinary ramp -- the
    -- exception is bought for the one magnitude that counts in whole steps, not for the item.
    utility_battle_casting = { ["traitParams.strikeRefund"] = true },
}

-- Every per-level row of every item, as (id, path, values). A footprint's shape/length/width/radius is
-- skipped: geometry is drawn, not counted (ui/footprint_diagram.lua), and a level that opens a line into
-- a cone is a level that bought something.
local function eachMagnitudeRow(fn)
    local ids = {}
    for id in pairs(Item.defs) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local function walk(t, path)
            local keys = {}
            for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local v, here = t[k], path .. "." .. k
                if type(v) == "table" and #v > 1 and type(v[1]) == "number" then
                    if not here:find("^activeAbility%.aoe%.") then fn(id, here, v) end
                elseif type(v) == "table" then
                    walk(v, here)
                end
            end
        end
        for _, name in ipairs(CONTAINERS) do
            if type(Item.defs[id][name]) == "table" then walk(Item.defs[id][name], name) end
        end
    end
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
        -- The point of the whole module: the ladder shows what each level buys, so each level had
        -- better buy something.
        name = "every level of a ramp steps up -- no two entries are the same",
        fn = function()
            for _, pair in ipairs({ { 4, 14 }, { 6, 16 }, { 3, 13 }, { 12, 24 }, { 24, 50 }, { 5, 40 } }) do
                local c = Curve.ramp(pair[1], pair[2])
                for i = 2, Curve.LEVELS do
                    assert(c[i] > c[i - 1], "ramp(" .. pair[1] .. ", " .. pair[2] .. ") holds at level "
                        .. (i - 1) .. ": { " .. table.concat(c, ", ") .. " }")
                end
            end
        end,
    },
    {
        name = "a span too short to move every level is refused, not silently rounded",
        fn = function()
            -- ramp(6, 14) is the shape this rule was written for: eight points of climb over ten
            -- levels, which printed 8, 8 and 12, 12 on the forge ladder.
            for _, pair in ipairs({ { 6, 14 }, { 2, 4 }, { 3, 8 }, { 1, 1 }, { 0, 0 }, { 5, 5 } }) do
                local ok = pcall(Curve.ramp, pair[1], pair[2])
                assert(not ok, "ramp(" .. pair[1] .. ", " .. pair[2] .. ") should have been refused:"
                    .. " a magnitude with that little climb in it is a plain number, not a curve")
            end
            -- And the refusal says what to do about it, since the author reading it has to choose.
            local _, err = pcall(Curve.ramp, 6, 14)
            assert(tostring(err):find("plain number"), "the message should name the alternative, got: "
                .. tostring(err))
        end,
    },
    {
        name = "a ramp spans exactly LEVELS entries and honours both endpoints",
        fn = function()
            for _, pair in ipairs({ { 4, 19 }, { 12, 24 }, { 24, 50 }, { -1, -11 } }) do
                local c = Curve.ramp(pair[1], pair[2])
                assert(#c == Curve.LEVELS, "ramp returned " .. #c .. " entries, expected " .. Curve.LEVELS)
                assert(c[1] == pair[1], "a ramp must start at its base, got " .. c[1])
                assert(c[Curve.LEVELS] == pair[2], "a ramp must finish at its top, got " .. c[Curve.LEVELS])
            end
        end,
    },
    {
        -- The single-argument form is the shape most blueprints want -- and doubling only clears the
        -- span rule from a base of LEVELS-1 up, which is exactly when it is offered.
        name = "a curve with no top doubles by the last forge level",
        fn = function()
            local c = Curve.ramp(12)
            assert(c[1] == 12 and c[Curve.LEVELS] == 24,
                "ramp(12) should run 12..24, got " .. c[1] .. ".." .. c[Curve.LEVELS])
            local ok = same(Curve.ramp(12), Curve.ramp(12, 24))
            assert(ok, "the one-argument form must equal spelling the doubled top out")
            assert(not pcall(Curve.ramp, 8), "ramp(8) doubles to 16, which cannot move ten levels")
        end,
    },
    {
        -- Lua's floor(x + 0.5) rounds half UP, not half away from zero, so without care a magnitude
        -- authored as a discount would bend differently from the identical gain. A blueprint should not
        -- have to know which side of zero it is on.
        name = "a descending curve is the exact mirror of the ascending one",
        fn = function()
            local up = Curve.ramp(1, 12)
            local down = Curve.ramp(-1, -12)
            for i = 1, Curve.LEVELS do
                assert(down[i] == -up[i], "a curve is asymmetric at level " .. (i - 1)
                    .. ": " .. down[i] .. " is not the negation of " .. up[i])
            end
            for i = 2, Curve.LEVELS do
                assert(down[i] < down[i - 1], "a descending curve rises at level " .. (i - 1))
            end
        end,
    },
    {
        -- The reason the generator returns a plain list rather than a closure or a lazy object:
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
    {
        -- The sweep. A magnitude may be a curve that moves at every level, or a plain number that never
        -- moves; the one thing it may not be is a curve that only sometimes moves, because the ladder
        -- and the price tag both read it as a level's worth of gold.
        name = "every tuned magnitude in the game moves at every forge level, or is not a curve",
        fn = function()
            local bad = {}
            eachMagnitudeRow(function(id, path, values)
                if STEP_CURVES[id] and STEP_CURVES[id][path] then return end
                for i = 2, Curve.LEVELS do
                    if values[i] == values[i - 1] then
                        bad[#bad + 1] = id .. "  " .. path .. " holds at level " .. (i - 1)
                            .. ": { " .. table.concat(values, ", ") .. " }"
                        return
                    end
                end
            end)
            assert(#bad == 0, #bad .. " magnitude(s) hold at some forge level, so that level buys"
                .. " nothing:\n  " .. table.concat(bad, "\n  ")
                .. "\n  (widen the top to base + " .. Item.MAX_LEVEL .. ", author it as a plain number,"
                .. " or name it in STEP_CURVES if it counts in whole steps)")
        end,
    },
    {
        -- The other half of the same rule, from the player's side: a bench that offers an upgrade is
        -- promising something for the gold.
        name = "no forgeable item has a level that buys nothing at all",
        fn = function()
            local ids, bad = {}, {}
            for id in pairs(Item.defs) do ids[#ids + 1] = id end
            table.sort(ids)
            for _, id in ipairs(ids) do
                -- `scalesWithLevel` items earn their level inside the effect (the warding wands add
                -- ticks off fx.level), which is real growth that Item.growth cannot chart -- there is no
                -- magnitude row to read. Skipped because the sweep cannot see them, not excused.
                if Item.isUpgradable(Item.instantiate(id, 1, 0)) and not Item.defs[id].scalesWithLevel then
                    local g = Item.growth(id)
                    local moved = {}
                    if g.footprint then
                        for _, lvl in ipairs(g.footprint.changedAt) do moved[lvl] = true end
                    end
                    for _, s in ipairs(g.stats) do
                        for lvl = 1, g.maxLevel do if s.changed[lvl] then moved[lvl] = true end end
                    end
                    local dead = {}
                    for lvl = 1, g.maxLevel do if not moved[lvl] then dead[#dead + 1] = lvl end end
                    -- The step-curve items are forgeable and DO hold at some levels; that is the
                    -- exception STEP_CURVES buys them, and it is bought once, not twice.
                    if #dead > 0 and not STEP_CURVES[id] then
                        bad[#bad + 1] = id .. " buys nothing at +" .. table.concat(dead, ", +")
                    end
                end
            end
            assert(#bad == 0, #bad .. " item(s) charge for a level that changes no number:\n  "
                .. table.concat(bad, "\n  "))
        end,
    },
}
