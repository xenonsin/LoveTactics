-- Per-level stat gains for a character growing as a necromancer (mage discipline).
-- Corpse-raise: dark resilience -- magic plus a second point of magic defence.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on necromancer stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- defense 1: grave-cold flesh takes a blow better than it looks. Survivability floor
    -- (Growth.ENEMY_DAMAGE_GROWTH) -- health alone grew slower than a scaled enemy's attack.
    magicDamage = 3, mana = 4, magicDefense = 2, health = 2, defense = 1,
}
