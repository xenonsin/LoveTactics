-- Per-level curve generators. An item's tuned magnitudes -- an ability's damage, armor's defense and
-- resists, a wait-swap's payoff -- are authored as a list over the forge levels 0..MAX_LEVEL, and
-- models/item.lua's resolveLevel reads this level's entry out of it. Those lists were hand-typed,
-- eleven integers at a time, across ~366 blueprints: about 5400 numbers carrying roughly two numbers
-- of information each, because almost every one of them is a straight line from its base to its top.
-- The other nine entries are rounding a human did by hand, and that no reviewer can check by eye.
--
-- So a blueprint says where the line starts and where it ends, and this module types the rest:
--
--     damage = Curve.ramp(6, 16)        -->  { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
--     resist = { slash = Curve.paired(3, 8) }
--
-- Both return a plain Lua list of exactly LEVELS entries, which is what the rest of the model already
-- expects -- nothing downstream knows a curve was generated rather than typed. That is deliberate:
-- resolveLevel, eachMagnitude, Item.growth and the whole of combat see what they have always seen.
--
-- There is NO override mechanism, on purpose. A curve whose shape neither generator reproduces
-- EXACTLY keeps its literal list; resolveLevel takes those unchanged, so the fallback costs nothing.
-- An override argument was tried and dropped -- `Curve.step(8, 1, { [9] = 18, [10] = 20 })` is harder
-- to read than the eleven integers it replaces, which defeats the point of writing it down at all.
--
-- Requires nothing, and must stay that way: blueprints under data/ load this at file scope, and
-- models/item.lua -> models/registry.lua -> each blueprint, so requiring anything from models/ here
-- would close a cycle.

local Curve = {}

-- How many forge levels a magnitude covers, counting level 0 -- so eleven entries for levels 0..10.
-- The single source of truth for the ceiling: models/item.lua derives Item.MAX_LEVEL from it rather
-- than carrying a second literal that could drift.
Curve.LEVELS = 11

-- Round half AWAY from zero, so a curve behaves the same on either side of it. Lua's usual
-- floor(x + 0.5) rounds half UP, which is asymmetric: it turns 2.5 into 3 but -2.5 into -2, so a
-- descending curve (a discount authored as negatives, like Quickened Sigil's speed bonus) would bend
-- differently from the identical ascending one. Positive curves -- every curve in the game today --
-- round exactly as floor(x + 0.5) always did.
local function round(x)
    if x < 0 then return -math.floor(-x + 0.5) end
    return math.floor(x + 0.5)
end

-- The shared generator. `gain(level)` says how far along the line each level sits; the two exported
-- styles differ only in that.
local function build(base, top, gain)
    assert(type(base) == "number", "a curve needs a numeric base, got " .. type(base))
    -- The overwhelmingly common shape is "twice as good, fully forged" -- so that is what one
    -- argument means, and a curve that doubles says so by leaving the top out.
    top = top or (base * 2)
    assert(type(top) == "number", "a curve needs a numeric top, got " .. type(top))
    local step = (top - base) / (Curve.LEVELS - 1)
    local out = {}
    for i = 1, Curve.LEVELS do
        out[i] = round(base + gain(i - 1) * step)
    end
    return out
end

-- A smooth line: every forge level moves the magnitude by the same fraction of the total climb.
-- The default shape, and the one most blueprints want.
--
--     Curve.ramp(8, 18)  -->  { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
--     Curve.ramp(8)      -->  the same, since the top defaults to twice the base
function Curve.ramp(base, top)
    return build(base, top, function(level) return level end)
end

-- The same line, climbed in PAIRS of levels: a magnitude holds for one level, then steps by two.
-- Same base, same top, same total gain -- only the phase of the half-step differs. Not a rounding
-- accident: it is how a good third of the game's curves were authored by hand, because a chunkier
-- step reads better on the forge ladder than a point that only sometimes arrives.
--
--     Curve.paired(3, 8)  -->  { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 }
function Curve.paired(base, top)
    return build(base, top, function(level) return 2 * math.floor(level / 2) end)
end

return Curve
