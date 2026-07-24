-- Per-level stat gains for a character growing as a herbalist (hunter x alchemist discipline).
-- Field brewing: converts the field -- a durable, resourceful mix.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on herbalist stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    mana = 3, magicDamage = 2, stamina = 3, health = 3,
}
