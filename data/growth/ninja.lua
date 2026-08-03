-- Per-level stat gains for a character growing as a ninja (rogue x mage discipline).
-- Shadowclone: blink and blade -- rogue speed carrying real magicDamage.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on ninja stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- health 3, bought with a point of stamina: like the assassin it branches beside, the ninja had no
    -- survivability growth at all and was one-shot by level 23. Taken in pool, not armour -- see
    -- Growth.ENEMY_DAMAGE_GROWTH.
    speed = 2, damage = 3, magicDamage = 3, stamina = 1, health = 3,
}
