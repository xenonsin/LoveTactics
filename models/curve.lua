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
--     resist = { slash = 3 }            -->  flat: not every magnitude is a growth axis (see below)
--
-- It returns a plain Lua list of exactly LEVELS entries, which is what the rest of the model already
-- expects -- nothing downstream knows a curve was generated rather than typed. That is deliberate:
-- resolveLevel, eachMagnitude, Item.growth and the whole of combat see what they have always seen.
--
-- THE ONE RULE: a curve must gain at least a point per forge level, so `top` sits at least LEVELS-1
-- above `base`. This is checked, not merely documented, because a curve that climbs less far than it
-- has levels MUST hold somewhere -- ramp(6, 14) spreads eight points over ten levels and prints
-- "8, 8" and "12, 12" on the ladder, which is the vendor charging 60 gold for a level that changes
-- nothing (models/vendor.lua's upgradeCost bills by target level, not by gain). A magnitude with less
-- than LEVELS-1 of climb in it is not a growth axis; it is part of the item's identity, so it is
-- authored as a PLAIN NUMBER (resolveLevel returns those unchanged at every level) and the item grows
-- on the stat that leads its tooltip instead. tools/curve_widen.lua brought the data under this rule
-- and tests/curve_spec.lua holds it there.
--
-- This is also why there is only ONE generator now. `Curve.paired` -- the same line climbed in pairs of
-- levels, holding for one and stepping by two -- existed because a third of the game's magnitudes were
-- hand-typed that way, and its holds are exactly the defect above: it could not step every level even
-- in principle. Its former call sites are ramps (where they lead) or plain numbers (where they do not).
--
-- There is NO override mechanism, on purpose. A curve whose shape the generator does not reproduce
-- EXACTLY keeps its literal list; resolveLevel takes those unchanged, so the fallback costs nothing --
-- and it is the escape hatch for the handful of magnitudes counted in WHOLE steps, where a point per
-- level is not a stronger item but a broken one: a ward's blows swallowed, a boot's tiles of movement
-- (tests/curve_spec.lua names them). An override argument was tried and dropped -- `Curve.step(8, 1,
-- { [9] = 18, [10] = 20 })` is harder to read than the eleven integers it replaces, which defeats the
-- point of writing it down at all.
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
-- magnitude authored as a deepening discount (negatives) would bend differently from the identical
-- gain. Every curve in the game today ascends -- a discount that deepens by a point per level would
-- have to reach -10, which is why Quickened Sigil's tempo bonus is now a flat -1 -- and those round
-- exactly as floor(x + 0.5) always did.
local function round(x)
    if x < 0 then return -math.floor(-x + 0.5) end
    return math.floor(x + 0.5)
end

-- A smooth line: every forge level moves the magnitude by the same fraction of the total climb, which
-- with the span rule above means by at least one whole point. The only shape there is.
--
--     Curve.ramp(8, 18)  -->  { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
--     Curve.ramp(12)     -->  the same idea, since the top defaults to twice the base
function Curve.ramp(base, top)
    assert(type(base) == "number", "a curve needs a numeric base, got " .. type(base))
    -- "Twice as good, fully forged" is the shape most blueprints want, so that is what one argument
    -- means -- available to any base of LEVELS-1 or more, since doubling a smaller one cannot climb far
    -- enough to move every level.
    top = top or (base * 2)
    assert(type(top) == "number", "a curve needs a numeric top, got " .. type(top))
    -- The span rule, in the one place every curve passes through. Measured on the ABSOLUTE climb so a
    -- magnitude authored as a discount (a negative curve) is held to the same standard as the identical
    -- gain, exactly as round() below is symmetric about zero.
    local span, need = math.abs(top - base), Curve.LEVELS - 1
    assert(span >= need, "a curve from " .. base .. " to " .. top .. " climbs " .. span
        .. " over " .. need .. " forge levels, so at least one level would buy nothing. Widen the top"
        .. " to at least " .. (base >= 0 and (base + need) or (base - need))
        .. ", or author it as a plain number if it is not what the item grows on.")
    local step = (top - base) / need
    local out = {}
    for i = 1, Curve.LEVELS do
        out[i] = round(base + (i - 1) * step)
    end
    return out
end

return Curve
