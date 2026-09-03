-- Per-level stat gains for a character growing as a battlemage (fighter x mage discipline).
-- Spellstrike: steel and spell in one motion -- an even split of arm and mana.
-- Its own growth path: a discipline item tallies the discipline itself, not its parent class(es)
-- (models/class.lua's growthClasses), so a build leaning on battlemage stock grows on THIS table.
-- Budget matches the base class tables (~10-12 points/level); movement is never grown (grid balance).
-- See data/growth/knight.lua for the base shape and tests/growth_spec.lua for the stat rules.
return {
    health = 3, damage = 2, magicDamage = 3, mana = 3,
}
