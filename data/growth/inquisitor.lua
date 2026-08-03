-- Per-level stat gains for a character growing as a inquisitor (rogue x priest discipline).
-- Judgment: a holy execution -- a rogue's strike lit by a priest's mana.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on inquisitor stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- A point of mana traded for a body and a little plate: health 1 alone left both channels under
    -- the survivability floor (Growth.ENEMY_DAMAGE_GROWTH). An inquisitor is an armoured zealot, so it
    -- takes the floor in armour on both sides rather than in pool.
    speed = 1, damage = 3, magicDamage = 2, mana = 2, health = 2, defense = 1, magicDefense = 1,
}
