-- RUNNER'S HIDE: the coat that makes you quick enough not to be bitten twice.
--
-- IT WAS GOING TO BE THE HIDE THAT COSTS NO MOVEMENT, and that item cannot exist. docs/classes.md's
-- cost table has no free rung and tests/armor_spec.lua enforces it: every coat is felt, and what
-- separates the tiers is how much it protects rather than whether you notice it. The rule is older than
-- this item and better argued -- a free tier meant the honest way to read the whole spread was "find
-- the pieces that are free and wear those", and four free pieces was a real build. So it pays its
-- square like everything else, and its identity moved somewhere the rule does not reach.
--
-- WHICH TURNED OUT TO BE THE BETTER ITEM ANYWAY. It buys SPEED, and speed is no longer just initiative:
-- the pack's own teeth strike twice against a body two points slower (weapon_wolf_fangs.lua, Fire
-- Emblem's doubling re-scaled to this game's 0-9 range). The cast sits in two clumps -- the heavies at
-- 3, the quick at 5 -- so one point off a wolf's coat is exactly the point that carries a speed-5 body
-- to 6 and puts the whole armoured half of every warband inside doubling range. A coat that decides
-- whether you get bitten once or twice is a build piece; a coat that saves you a step was a convenience.
--
-- IT USED TO BE HALF AN ARGUMENT ABOUT THE PLAYER'S OWN DOUBLING, and that half is gone: it read
-- "weapon_the_second_bite hands that same rule to the player" back when that blade rolled the speed
-- gap too. It is a BRAVE weapon now (`strikes = 2`, docs/weapons.md) -- it strikes twice whoever it is
-- aimed at, so no coat buys it anything. The doubling rule is the pack's alone, which means this hide
-- is bought to be doubled LESS rather than to double more, and that is the honest reading of a wolf's
-- skin anyway. The initiative it buys is untouched, and so is every use of it.
--
-- It also reads as the animal, which the movement line never quite did. You do not take a wolf's hide
-- and become untiring. You take it and become faster than the thing in front of you.
--
-- MOVEMENT AND SPEED ARE DIFFERENT STATS and the pairing is the trade, not a contradiction: it costs a
-- square of ground per turn and buys a place in the order. Cross less, act sooner, and land the second
-- bite when you get there.
--
-- Defense sits one point under armor_bristlehide's at every forge rung (2->12 there, 1->11 here),
-- because the speed is the thing being paid for. Read against that coat it is a real decision.
--
-- ONE RESIST, AND IT IS POSITIVE. The wolf blueprints carry `slash 2 / impact -2` -- hide turns a blade
-- and does nothing about weight -- but an armour may not sell a negative resist: exactly one does
-- (armor_reckless_cuirass) and tests/armor_spec.lua keeps it that way, because a coat that makes you
-- WORSE against a damage type is a wager rather than a coat. What a creature wears is allowed to be a
-- trade in both directions; what a person buys is not (docs/bestiary.md).
--
-- Comes off the commonest animal on the road, which is where a piece that teaches the doubling rule
-- belongs -- you meet the rule from the wrong end of it first. Class `hunter`, unpriced; `dropTier` is
-- set by the grading pass (`. drop-tier`) rather than chosen here.
local Curve = require("models.curve")

return {
    name = "Runner's Hide",
    description = "Increase Speed by 1. Turns blades. Costs a square of movement, like every coat.",
    flavor = "Skinned in one piece by somebody in a hurry, which is the only way anyone has ever got one.",
    sprite = "assets/items/armor_runners_hide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    unlockLevel = 2,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    -- The span is 10 because Curve.ramp asserts a climb of at least Curve.LEVELS - 1 (a point per forge
    -- rung, so no level a player pays for buys them nothing). Speed is a whole-step stat -- identity,
    -- not growth -- so it is a plain number, which is the other half of that same rule.
    bonus = { defense = Curve.ramp(1, 11), movement = -1, speed = 1 },
    resist = { slash = 2 },
}
