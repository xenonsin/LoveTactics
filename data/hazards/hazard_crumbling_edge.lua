-- CRUMBLING EDGE: a ring of the board's edge the Hollow Crown has marked (models/hollow_crown.lua, phase 3; slice D).
-- Each of the Crown's turns it marks the next ring in and drops the ring it marked the turn before into the Pit: a
-- body standing on it then is Downed, and Pit Locusts climb out. Marked a turn ahead, so the company always has a
-- turn to step off.
--
-- It does nothing while it waits. HOSTILE, so every planner reads it as ground to leave.
return {
    name = "Crumbling Edge",
    description = "Falls into the Pit on the Crown's next turn. A body standing here then is Downed.",
    tags = {},
    duration = 9999, -- lifted when it falls, never by the clock
    disposition = "hostile",
}
