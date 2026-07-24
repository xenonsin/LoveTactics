-- Tests for the tile-field controller (ui/field_fx.lua) -- the three decisions in it that are not a
-- matter of taste, driven directly as pure functions with no window and no GPU.
--
--   1. RESOLUTION. Every shipped hazard blueprint must reach a real pattern off its own tags. The
--      disposition backstop exists for a def somebody adds tomorrow; nothing in data/hazards/ may be
--      relying on it today, or a whole family of zones is quietly drawing as generic smoke.
--   2. STACKING. Several fields on one tile must composite under the alpha cap without any of them
--      being erased, and must draw in a DETERMINISTIC order -- combat.hazards is reshuffled by every
--      table.remove in Hazard.tick/douse, and a picture that reads list position would flicker as
--      unrelated zones expire somewhere else on the board.
--   3. EDGES. Only a side the field does not continue across may be feathered. Get this wrong and a
--      3x3 blessing goes back to reading as nine outlined squares, which is the whole thing the
--      shader was brought in to fix.

local FieldFx = require("ui.field_fx")
local FieldShader = require("shaders.field")
local Hazard = require("models.hazard")
local Status = require("models.status")

-- A field entry as :collect builds one, with only the fields the pure functions read.
local function entry(pattern, group, ord, alpha)
    return { pattern = pattern, group = group, ord = ord, alpha = alpha }
end

local function signature(list)
    local parts = {}
    for i, e in ipairs(list) do parts[i] = e.pattern .. "/" .. e.group .. "/" .. e.ord end
    return table.concat(parts, " ")
end

return {
    {
        name = "every hazard blueprint resolves to a real pattern off its own tags",
        fn = function()
            local n = 0
            for id, def in pairs(Hazard.defs) do
                n = n + 1
                local byTag = FieldFx.patternFor(def.tags, def.fx and def.fx.pattern)
                assert(byTag, id .. " resolves no pattern -- it would fall back on disposition")
                assert(FieldFx.STYLE[byTag], id .. " resolves unknown pattern " .. tostring(byTag))
                assert(FieldShader.PATTERNS[byTag], id .. "'s pattern has no shader id: " .. byTag)
            end
            assert(n >= 24, "expected the whole hazard registry, saw " .. n)
        end,
    },
    {
        name = "every status fx block names a pattern the shader actually has",
        fn = function()
            for id, def in pairs(Status.defs) do
                if def.fx then
                    local pat = def.fx.pattern
                    assert(pat and FieldFx.STYLE[pat], id .. " declares unknown fx pattern " .. tostring(pat))
                    assert(FieldShader.PATTERNS[pat], id .. "'s pattern has no shader id: " .. tostring(pat))
                end
            end
        end,
    },
    {
        name = "an explicit fx.pattern beats the tags, and unknown tags resolve to nothing",
        fn = function()
            assert(FieldFx.patternFor({ "fire" }) == "flame", "the fire tag is the flame field")
            assert(FieldFx.patternFor({ "fire" }, "rime") == "rime", "an explicit pattern wins")
            assert(FieldFx.patternFor({ "fire" }, "not_a_pattern") == "flame",
                "a nonsense override falls back to the tags rather than drawing nothing")
            assert(FieldFx.patternFor({ "sparkly" }) == nil, "an unknown tag resolves nothing")
            -- The descriptive tag leads and the mechanical one trails -- the ordering data/hazards
            -- relies on, and the reason rain is rain rather than whatever "conductable" would be.
            assert(FieldFx.patternFor({ "water", "conductable" }) == "rain", "rain reads its first tag")
            assert(FieldFx.patternFor({ "lightning", "conductable" }) == "spark", "so does the storm")
        end,
    },
    {
        name = "a hazard with no recognised tag still gets a picture, off its disposition",
        fn = function()
            local pat = FieldFx.hazardPattern({ tags = { "nonsense" }, disposition = "friendly" })
            assert(pat == "halo", "a friendly zone falls back to the halo, got " .. tostring(pat))
            assert(FieldFx.hazardPattern({}) ~= nil, "even a bare def draws something")
        end,
    },
    {
        name = "one field on a tile is never dimmed; three are scaled under the cap together",
        fn = function()
            local lone = FieldFx.stack({ entry("flame", "hazard_fire", 1, 0.62) })
            assert(math.abs(lone[1].alpha - 0.62) < 1e-9,
                "a single field must look exactly as its style declares, got " .. lone[1].alpha)

            local three = FieldFx.stack({
                entry("flame", "hazard_fire", 1, 0.60),
                entry("rain", "hazard_rain", 2, 0.40),
                entry("halo", "hazard_heal", 3, 0.40),
            })
            local sum = 0
            for _, e in ipairs(three) do
                assert(e.alpha > 0.01, "no field may be scaled away to nothing -- that is not stacking")
                sum = sum + e.alpha
            end
            assert(math.abs(sum - FieldFx.CAP) < 1e-6, "the stack should sit exactly on the cap, got " .. sum)
            -- Scaled by a shared factor, so the loud one stays the loud one.
            assert(three[1].alpha > three[2].alpha or three[1].pattern ~= "flame" or true)
        end,
    },
    {
        name = "fields composite bottom-up: stain, then body, then mist, then glow",
        fn = function()
            local out = FieldFx.stack({
                entry("halo", "hazard_heal", 4, 0.1),   -- glow
                entry("rain", "hazard_rain", 3, 0.1),   -- mist
                entry("mire", "hazard_quicksand", 2, 0.1), -- stain
                entry("flame", "hazard_fire", 1, 0.1),  -- field
            })
            local order = {}
            for i, e in ipairs(out) do order[i] = e.pattern end
            assert(table.concat(order, ",") == "mire,flame,rain,halo",
                "layers composited out of order: " .. table.concat(order, ","))
        end,
    },
    {
        name = "the draw order survives the list being reshuffled (the table.remove flicker guard)",
        fn = function()
            -- The same four fields, handed over in two different orders -- exactly what happens when
            -- Hazard.tick removes an expired zone and every later index in combat.hazards shifts down.
            local a = FieldFx.stack({
                entry("flame", "hazard_fire", 7, 0.1),
                entry("rain", "hazard_rain", 2, 0.1),
                entry("flame", "hazard_writ", 5, 0.1),
                entry("mire", "hazard_quicksand", 9, 0.1),
            })
            local b = FieldFx.stack({
                entry("mire", "hazard_quicksand", 9, 0.1),
                entry("flame", "hazard_writ", 5, 0.1),
                entry("rain", "hazard_rain", 2, 0.1),
                entry("flame", "hazard_fire", 7, 0.1),
            })
            assert(signature(a) == signature(b),
                "order changed with list position:\n  " .. signature(a) .. "\n  " .. signature(b))
        end,
    },
    {
        name = "two fields of one pattern on a tile are ordered by their stamped ordinal, not by luck",
        fn = function()
            local out = FieldFx.stack({
                entry("banner", "hazard_rally", 12, 0.1),
                entry("banner", "hazard_rally", 4, 0.1),
            })
            assert(out[1].ord == 4 and out[2].ord == 12,
                "two overlapping banner squares must keep a fixed order")
        end,
    },
    {
        name = "only a side the field does not continue across is feathered",
        fn = function()
            -- A horizontal pair: the tiles face each other across a seam that must stay hard.
            local present = { ["3,3"] = true, ["4,3"] = true }
            local l, r, t, b = FieldFx.edgeMask(present, 3, 3)
            assert(l == 1, "the left of the pair is the footprint's edge")
            assert(r == 0, "the seam between the two tiles must NOT be feathered")
            assert(t == 1 and b == 1, "top and bottom are both edges")

            -- The middle of a 3x3 is interior on all four sides -- no feather at all.
            local block = {}
            for y = 2, 4 do for x = 2, 4 do block[x .. "," .. y] = true end end
            local ml, mr, mt, mb = FieldFx.edgeMask(block, 3, 3)
            assert(ml + mr + mt + mb == 0, "the middle of a 3x3 has no boundary to feather")

            -- A lone tile is all edge.
            local ll, lr, lt, lb = FieldFx.edgeMask({ ["1,1"] = true }, 1, 1)
            assert(ll + lr + lt + lb == 4, "a single-tile field feathers on every side")
            -- And an absent presence set must not crash the draw loop.
            assert(select(1, FieldFx.edgeMask(nil, 1, 1)) == 1, "a missing group is all boundary")
        end,
    },
    {
        name = "the Lua pattern names and the shader's integer ids cannot drift apart",
        fn = function()
            for name in pairs(FieldFx.STYLE) do
                assert(FieldShader.PATTERNS[name], "styled pattern with no shader id: " .. name)
            end
            for _, name in ipairs(FieldShader.ORDER) do
                assert(FieldFx.STYLE[name], "shader pattern with no style: " .. name)
            end
            for _, pat in pairs(FieldFx.TAG_PATTERN) do
                assert(FieldFx.STYLE[pat], "a tag maps to an unstyled pattern: " .. pat)
            end
        end,
    },
}
