-- Per-level stat gains for a character growing as a artificer (mage x alchemist discipline).
-- Constructs: an engine-builder -- mage magic with the mana to field sentries.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on artificer stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- defense 1: an artificer plates itself the way it plates its constructs. Survivability floor
    -- (Growth.ENEMY_DAMAGE_GROWTH) -- health alone grew slower than a scaled enemy's attack.
    magicDamage = 3, mana = 5, health = 2, magicDefense = 1, defense = 1,
}
