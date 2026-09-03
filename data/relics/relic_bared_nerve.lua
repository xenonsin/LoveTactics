-- UNCOMMON. The only relic on the shelf whose value is set by WHO YOU ARE ABOUT TO FIGHT rather than by
-- how you play. Every other trade on this rung is answered the same way on every floor; this one is
-- correct in a circle that casts and wrong in one that swings -- and a descent names what is below
-- before you take the stair, so the information to price it is always in front of you.
--
-- Trades within the armour pair rather than across the attack/defense line, so it never simply nets out
-- against The Keen Edge: a company can hold both and be a different shape for it.
return {
    name = "The Bared Nerve",
    blurb = "+%d magic defense for the whole company.",
    tier = "uncommon", mark = "Bn",
    cost = "-%d defense against blades.",
    costScale = { 4, 2 },
    scale = { 5, 3 },
    bonus = { magicDefense = 5, defense = -4 },
    bonusStep = { magicDefense = 3, defense = -2 },
}
