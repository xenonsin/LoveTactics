-- Per-level stat gains for a character growing as a apothecary (priest x alchemist discipline).
-- Lent vitality: mends before it strikes -- a supporting caster's growth.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on apothecary stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    mana = 5, magicDamage = 2, health = 3, magicDefense = 1,
}
