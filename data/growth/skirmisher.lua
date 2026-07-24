-- Per-level stat gains for a character growing as a skirmisher (fighter x hunter discipline).
-- Hit-and-run: mobile damage -- reposition, then strike.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on skirmisher stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    damage = 3, stamina = 3, speed = 2, health = 2,
}
