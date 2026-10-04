-- WAKING ROW: a row Desidia will sweep when she wakes (The Long Sleep, models/desidia.lua; "Sloth's Bestiary",
-- slice G). Every turn she sleeps through banks one more turn, and each banked turn is a sweep down the row it
-- marked as it was banked -- so the board fills with her rows the longer she is left alone, and all of them come
-- due at once.
--
-- It does nothing until she wakes. HOSTILE, so every planner reads the row as ground to leave.
return {
    name = "Waking Row",
    description = "Desidia sweeps this row once for every turn she banked on it, when she wakes.",
    tags = { "ice" },
    duration = 9999, -- lifted when she wakes, never by the clock
    disposition = "hostile",
}
