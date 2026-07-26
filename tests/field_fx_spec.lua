-- Tests for the tile-field controller (ui/field_fx.lua) -- the decisions in it that are not a matter
-- of taste, driven directly as pure functions with no window and no GPU.
--
--   1. CATEGORY. Every shipped hazard must read as one of the four category looks, and the look it
--      reads as must follow from what the zone DOES and whose side owns it -- a heal blue for your
--      side and red for theirs, a buff green, a threat orange. This is the whole point of the redesign,
--      so it is the thing most worth pinning down.
--   2. STACKING. Several fields on one tile must composite under the alpha cap without any of them
--      being erased, and must draw in a DETERMINISTIC order -- combat.hazards is reshuffled by every
--      table.remove in Hazard.tick/douse, and a picture that reads list position would flicker as
--      unrelated zones expire somewhere else on the board.
--   3. EDGES. Only a side the field does not continue across may be feathered. Get this wrong and a
--      3x3 blessing goes back to reading as nine outlined squares.

local FieldFx = require("ui.field_fx")
local FieldShader = require("shaders.field")
local Hazard = require("models.hazard")

-- A field entry as :collect builds one, with only the fields the pure functions read.
local function entry(pattern, group, ord, alpha)
    return { pattern = pattern, group = group, ord = ord, alpha = alpha }
end

local function signature(list)
    local parts = {}
    for i, e in ipairs(list) do parts[i] = e.pattern .. "/" .. e.group .. "/" .. e.ord end
    return table.concat(parts, " ")
end

-- A runtime hazard as the collector sees one: an id, its blueprint, and (optionally) an owning side.
local function haz(id, side)
    return { id = id, def = Hazard.defs[id], side = side, alive = true }
end

return {
    {
        name = "every hazard blueprint reads as a real category the shader can draw",
        fn = function()
            local n = 0
            for id in pairs(Hazard.defs) do
                n = n + 1
                local cat = FieldFx.hazardCategory(haz(id))
                local look = FieldFx.CATEGORY[cat]
                assert(look, id .. " resolves no category, got " .. tostring(cat))
                assert(FieldFx.STYLE[look.shape], id .. "'s category has an unstyled shape " .. tostring(look.shape))
                assert(FieldShader.PATTERNS[look.shape], id .. "'s shape has no shader id: " .. look.shape)
            end
            assert(n >= 24, "expected the whole hazard registry, saw " .. n)
        end,
    },
    {
        name = "a hazard's category follows what it does, and whose side owns it",
        fn = function()
            -- A threat is orange, regardless of owner.
            assert(FieldFx.hazardCategory(haz("hazard_fire")) == "hostile", "fire is a threat")
            -- The neutral zones fold in with the threats (Rain, Darkness) -- one look for "watch this
            -- ground", per the design call.
            assert(FieldFx.hazardCategory(haz("hazard_rain")) == "hostile", "rain folds into hostile")
            assert(FieldFx.hazardCategory(haz("hazard_darkness")) == "hostile", "darkness folds into hostile")

            -- A heal is blue on your side, red on theirs -- the one distinction the player most needs.
            assert(FieldFx.hazardCategory(haz("hazard_heal", "party")) == "heal_ally", "your sanctuary mends you")
            assert(FieldFx.hazardCategory(haz("hazard_heal", "enemy")) == "heal_enemy", "their sanctuary is red")

            -- A buff is green on your side, red on theirs.
            assert(FieldFx.hazardCategory(haz("hazard_rally", "party")) == "buff_ally", "your rally is green")
            assert(FieldFx.hazardCategory(haz("hazard_rally", "enemy")) == "buff_enemy", "their rally is red")

            -- Muster is neutral to the AI but reads friendly by its fx.valence override -- a buff, not a
            -- threat, and not a heal.
            assert(FieldFx.hazardCategory(haz("hazard_muster", "party")) == "buff_ally",
                "muster reads as your buff, not a threat")
        end,
    },
    {
        name = "a carried status reads by its nature: a debuff threatens, a mend heals, a boon buffs",
        fn = function()
            local burn = { debuff = true }
            local regen = { restorative = true }
            local aegis = {} -- a buff carries neither flag
            assert(FieldFx.statusCategory(burn, "party") == "hostile", "a debuff is a threat on any body")
            assert(FieldFx.statusCategory(burn, "enemy") == "hostile", "even on an enemy body")
            assert(FieldFx.statusCategory(regen, "party") == "heal_ally", "your regen is blue")
            assert(FieldFx.statusCategory(regen, "enemy") == "heal_enemy", "their regen is red")
            assert(FieldFx.statusCategory(aegis, "party") == "buff_ally", "your buff is green")
            assert(FieldFx.statusCategory(aegis, "enemy") == "buff_enemy", "their buff is red")
        end,
    },
    {
        name = "a telegraph previews the category of the cast it is steering",
        fn = function()
            assert(FieldFx.telegraphCategory(false) == "hostile", "an attack telegraphs as a threat")
            assert(FieldFx.telegraphCategory(true) == "buff_ally", "a support cast telegraphs as your buff")
            assert(FieldFx.telegraphCategory(true, true) == "heal_ally", "a heal telegraphs as your heal")
        end,
    },
    {
        name = "one field on a tile is never dimmed; three are scaled under the cap together",
        fn = function()
            local lone = FieldFx.stack({ entry("chevron", "hazard_fire", 1, 0.56) })
            assert(math.abs(lone[1].alpha - 0.56) < 1e-9,
                "a single field must look exactly as its style declares, got " .. lone[1].alpha)

            local three = FieldFx.stack({
                entry("chevron", "hazard_fire", 1, 0.56),
                entry("chevron", "hazard_rally", 2, 0.56),
                entry("cross", "hazard_heal", 3, 0.64),
            })
            local sum = 0
            for _, e in ipairs(three) do
                assert(e.alpha > 0.01, "no field may be scaled away to nothing -- that is not stacking")
                sum = sum + e.alpha
            end
            assert(math.abs(sum - FieldFx.CAP) < 1e-6, "the stack should sit exactly on the cap, got " .. sum)
        end,
    },
    {
        name = "the draw order survives the list being reshuffled (the table.remove flicker guard)",
        fn = function()
            -- The same four fields, handed over in two different orders -- exactly what happens when
            -- Hazard.tick removes an expired zone and every later index in combat.hazards shifts down.
            local a = FieldFx.stack({
                entry("chevron", "hazard_fire", 7, 0.1),
                entry("cross", "hazard_heal", 2, 0.1),
                entry("chevron", "hazard_writ", 5, 0.1),
                entry("chevron", "hazard_quicksand", 9, 0.1),
            })
            local b = FieldFx.stack({
                entry("chevron", "hazard_quicksand", 9, 0.1),
                entry("chevron", "hazard_writ", 5, 0.1),
                entry("cross", "hazard_heal", 2, 0.1),
                entry("chevron", "hazard_fire", 7, 0.1),
            })
            assert(signature(a) == signature(b),
                "order changed with list position:\n  " .. signature(a) .. "\n  " .. signature(b))
        end,
    },
    {
        name = "two fields of one shape on a tile are ordered by their stamped ordinal, not by luck",
        fn = function()
            local out = FieldFx.stack({
                entry("chevron", "hazard_rally", 12, 0.1),
                entry("chevron", "hazard_rally", 4, 0.1),
            })
            assert(out[1].ord == 4 and out[2].ord == 12,
                "two overlapping rally squares must keep a fixed order")
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
        name = "the Lua shape names and the shader's integer ids cannot drift apart",
        fn = function()
            for name in pairs(FieldFx.STYLE) do
                assert(FieldShader.PATTERNS[name], "styled shape with no shader id: " .. name)
            end
            for _, name in ipairs(FieldShader.ORDER) do
                assert(FieldFx.STYLE[name], "shader shape with no style: " .. name)
            end
            -- Every category names a shape the shader can draw.
            for cat, look in pairs(FieldFx.CATEGORY) do
                assert(FieldFx.STYLE[look.shape], cat .. " names an unstyled shape: " .. tostring(look.shape))
                assert(FieldShader.PATTERNS[look.shape], cat .. "'s shape has no shader id: " .. tostring(look.shape))
            end
        end,
    },
}
