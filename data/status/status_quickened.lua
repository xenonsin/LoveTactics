-- Quickened: the next action comes round sooner. Combat.actionSpeed takes `magnitude` ticks off the
-- one action it bills, and the action spends the badge (Engine.afterCast, models/engine.lua).
--
-- What the engines pay a body in TIME: the hunter's Carrion Mark when the marked foe falls, the
-- monk's Overflowing Cup when a full bank is spent. A timeline game's most honest reward is a turn
-- that arrives early, and this is the smallest one that can be read off the strip.
return {
    name = "Quickened",
    abbr = "Qk",
    description = "Quickened: its next action costs 2 less time.",
    color = { 0.95, 0.86, 0.45 }, -- badge tint (initiative gold)
    duration = 15, -- ~3 turns to spend it in
    magnitude = 2,
}
