-- Per-level stat gains for a character growing as a theurge (mage x priest discipline).
-- Channelled miracle: the deepest caster -- mana above all, held magic defence.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/discipline.lua's growthClasses), so a build leaning on theurge stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    -- Two points of mana traded for a body: the theurge grew no health and no armour, so it was
    -- one-shot by level 19 -- the deepest caster in the game could not survive being walked up to.
    -- mana 6 -> 4 pays for health 2 + defense 1, clearing the survivability floor on both channels
    -- (Growth.ENEMY_DAMAGE_GROWTH) while mana 4 keeps it the deepest pool of any priest discipline.
    magicDamage = 3, mana = 4, magicDefense = 2, health = 2, defense = 1,
}
