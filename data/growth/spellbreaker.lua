-- Per-level stat gains for a character growing as a spellbreaker (knight x mage discipline).
-- Counterspell: anti-mage steel -- the heaviest magic defence in the tree.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on spellbreaker stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 4, defense = 2, magicDefense = 3, damage = 2,
}
