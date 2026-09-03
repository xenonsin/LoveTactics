-- Per-level stat gains for a character growing as a assassin (rogue discipline).
-- Blink-execute: speed and damage, almost no bulk -- the burst archetype.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on assassin stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- health 3, bought with a point of stamina: the assassin had NO survivability growth at all, so a
    -- scaled enemy's +3 attack outran it outright and it was one-shot by level 23. It takes the floor
    -- (Growth.ENEMY_DAMAGE_GROWTH) entirely in pool -- an assassin buys life, never plate -- and keeps
    -- damage 5, which is the top of the physical ladder and the whole point of the archetype.
    speed = 2, damage = 5, stamina = 2, health = 3,
}
