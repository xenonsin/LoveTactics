-- HEART FED: Heart of Gold has healed its bearer this turn (models/golem.lua, Golem.took). A turn long,
-- so a thief who takes twice in one turn heals once -- round 2's cap, because Chipped Gold pays on every
-- blow and a fast hitter would otherwise drink on each one.
return {
    name = "Heart Fed",
    abbr = "Fed",
    description = "Heart of Gold has healed you this turn.",
    color = { 0.886, 0.600, 0.300 }, -- badge tint (warm gold)
    duration = 5, -- a turn (Status.TICKS_PER_TURN; not required here, the status registry is mid-load)
    hideLog = true,
}
