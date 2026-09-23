-- Ruptured Font: the Magic Damage half of data/injuries/injury_ruptured_font.lua. The quarter of the
-- mana pool it seals is not here -- a reservation rides `char.injuryShare` and Combat.unreservedMax.
--
-- THREE POINTS, MATCHING TORN SHOULDER'S, because it is the same injury pointed at the other half of the
-- roster and a caster's blow should not be cheaper to break than a swordsman's. What separates the two
-- is the reserve beside it: a mage's problem is rarely the size of one spell and always how many of them
-- there are before the pool is empty, so the heavier half of this injury is the ceiling it takes off the
-- mana rather than the points it takes off the blow.
--
-- See data/status/status_shattered_leg.lua for why `debuff = false`.
return {
    name = "Ruptured Font",
    abbr = "Font",
    description = "Ruptured Font: casts for less, and cannot fill the pool.",
    color = { 0.400, 0.384, 0.608 }, -- badge tint (spent violet)
    duration = 9999,
    debuff = false,
    statBonus = { magicDamage = -3 },
}
