-- BANKED: turns put by for later ("Sloth's Bestiary", 2026-10-04). The brief's "a body that banks the turns it
-- skips". Worn by the Ground Sloth (to 3), the Old Sloth (to 5) and Desidia (no cap).
--
-- THE STATUS IS ONLY THE COUNT. How a bank is earned and what it is spent on belong to the body that keeps it -- a
-- sloth's flurry, the Old Sloth's ring sweeps, Desidia's row sweeps -- and go through models/bank.lua, which also
-- holds each keeper to its own cap. `stacks` here is only a ceiling high enough that no keeper meets it.
--
-- Not a debuff and undispellable: a Cure that emptied a sloth's bank would be a free answer to the whole line.
return {
    name = "Banked",
    abbr = "Bank",
    description = "Banked: turns saved up. They are all spent at once.",
    color = { 0.620, 0.560, 0.380 }, -- badge tint (old brass)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    magnitude = 1,
    stacks = 99,
}
