-- Acid: a corrosive debuff that eats armor. It carries no tick of its own -- instead it lowers the
-- drenched unit's effective defenses for as long as it lasts: `statBonus = { defense = -N,
-- magicDefense = -N }` is folded into flatStat (models/combat.lua) exactly like a positive bonus,
-- so a defense of 8 reads as 8 - N while the acid clings. Every hit the unit then takes bites deeper.
-- Inflicted by an Acid Bomb (data/items/consumable/consumable_acid_bomb.lua); "removes the effects of armor"
-- for a duration, and Cure / Panacea (a negative statBonus is a debuff) wash it off early.
--
-- Modelled as a stat drop rather than `vulnerable`: the point is that the target's armor stops
-- working, so a heavily-armored foe loses the most, and the effect is the same whatever hits it.
return {
    name = "Acid",
    abbr = "Acd",
    description = "Corroded: defense and magic defense are reduced.",
    color = { 0.62, 0.78, 0.18 }, -- badge tint (caustic yellow-green)
    duration = 8, -- ~1.5 turns at Status.TICKS_PER_TURN (was under one, and so barely landed)
    debuff = true, -- removable by Cure / Panacea
    statBonus = { defense = -6, magicDefense = -6 }, -- armor eaten away while it lasts
}
