-- THE LINE: the Reaper's ("The Crown's Bestiary", slice C, approved 2026-10-09; carried on
-- data/items/utility/utility_the_line.lua). "A line on every health bar shows the threshold."
--
-- The rule itself lives in the scythe (weapon_reapers_scythe: a foe in its sweep under a quarter is downed at once).
-- This is the promise the board makes about it: while a body wearing `harvestLine` stands, every health bar draws a
-- tick at a quarter (GatePit.line, read by ui/battle_map.lua), so who is under the line is read at a glance and not
-- worked out.
return {
    name = "The Line",
    description = "While it stands, every health bar shows a line at a quarter. Under it, its sweep downs you.",
    harvestLine = true,
}
