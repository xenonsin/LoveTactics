-- Per-level stat gains for a character growing as a MAGE (pride's class): the glass cannon.
-- See data/growth/knight.lua for the shape.
return {
    magicDamage = 3,
    mana = 5,
    magicDefense = 1,
    health = 2,
    -- A glass cannon still has to survive being reached. Health alone (+2) grew slower than a scaled
    -- enemy's attack (+3), which one-shot a mage from level 13; this is the survivability floor, and
    -- it is armour rather than pool so the cannon stays glass. See Growth.ENEMY_DAMAGE_GROWTH.
    defense = 1,
}
