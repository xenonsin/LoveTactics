-- Per-level stat gains for a character growing as a paladin (knight x priest discipline).
-- Ward aura: the holy knight -- a wall that also heals.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on paladin stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 5, defense = 2, magicDamage = 2, mana = 2,
}
