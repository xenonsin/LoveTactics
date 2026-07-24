-- Per-level stat gains for a character growing as a totemist (hunter x priest discipline).
-- Ward totems: planted holy ground -- mana and health, a supporting body.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on totemist stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    mana = 4, magicDamage = 2, health = 3, stamina = 2,
}
