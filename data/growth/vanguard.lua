-- Per-level stat gains for a character growing as a vanguard (knight x rogue discipline).
-- Breach: strips guard and opens the line -- a knight's frame with a rogue's edge.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on vanguard stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 4, damage = 2, defense = 2, speed = 1, stamina = 2,
}
