-- RARE. The satchel stops running dry. A draught drunk in a fight is not used up -- the flask goes back
-- in the bag -- and the drinker pays for keeping it down out of its own health ceiling.
--
-- ONCE PER BODY PER TURN: a second draught in the same turn is spent as ever, so the relic is a steady
-- supply rather than a body that drinks its whole satchel for free in one burst. The toll wounds and
-- never fells (models/combat.lua's Combat.spareDraught).
--
-- THE LADDER IS THE PRICE, and it falls: 15% of maximum health, 3 points off per further copy, never
-- under 5%. The one rare whose stack pays down its own cost, because the inversion has no magnitude to
-- grow -- a flask cannot be more not-used-up.
local function toll(n) return math.max(5, 15 - 3 * (math.max(1, n) - 1)) end

return {
    name = "The Iron Stomach",
    blurb = "A draught drunk in a fight is not used up -- once per body per turn.",
    tier = "rare", mark = "Is",
    cost = "Each one costs the drinker %d%% of maximum health.",
    costScale = toll,
    rules = { ironStomach = true },
    ruleScale = { ironStomach = toll },
}
