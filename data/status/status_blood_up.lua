-- BLOOD UP: the orc Berserker's streak (data/traits/trait_blood_up.lua; 2026-09-26, "The Orcs of Wrath"). +3
-- Damage for each turn in a row it has landed a hit. While it holds, the Berserker must strike every turn, and
-- with no foe in reach it hits the nearest body, orc included (models/rampage.lua). The first turn it lands
-- nothing, the stacks go and it is Spent.
return {
    name = "Blood Up",
    abbr = "Up",
    description = "Blood Up: more damage for each turn in a row it has landed a hit. It must strike every turn.",
    color = { 0.760, 0.160, 0.120 }, -- badge tint (fresh blood)
    duration = math.huge,
    hideDuration = true,
    magnitude = 1,
    stacks = 5,
    statBonus = { damage = 3 },
    statBonusScales = true,
}
