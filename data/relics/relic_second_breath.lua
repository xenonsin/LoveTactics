-- COMMON. staminaRegen is a FLAT stat, not a resource -- stamina recovered per elapsed tick -- so this
-- buys time rather than a pool. The distinction matters: The Deep Draught lets a body spend more in one
-- burst, this lets it keep spending, and a long fight wants the second one.
return {
    name = "The Second Breath",
    blurb = "+%d stamina recovered each tick, for the whole company.",
    tier = "common", mark = "Br",
    scale = { 1, 1 },
    bonus = { staminaRegen = 1 },
}
