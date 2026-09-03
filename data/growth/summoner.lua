-- Per-level stat gains for a character growing as a summoner (mage discipline).
-- Reserve court: banks mana, so mana runs deepest of any growth here.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on summoner stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- defense 1: what it calls up stands between it and the blow. Survivability floor
    -- (Growth.ENEMY_DAMAGE_GROWTH) -- health alone grew slower than a scaled enemy's attack.
    magicDamage = 2, mana = 6, magicDefense = 1, health = 2, defense = 1,
}
