-- Per-level stat gains for a character growing as a saboteur (rogue x alchemist discipline).
-- Planted charges: stealth demolitions -- stamina to place, magic to detonate.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on saboteur stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    speed = 1, damage = 2, magicDamage = 2, stamina = 3, health = 2,
}
