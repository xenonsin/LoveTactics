-- Per-level stat gains for a character growing as a druid (hunter discipline).
-- Wildshape: a hybrid body that carries a little magic into its beast forms.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on druid stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 4, stamina = 3, damage = 2, magicDamage = 1,
}
