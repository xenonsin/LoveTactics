-- RARE. Mercy as a weapon. Every heal the company casts lands at half, and what it would have restored
-- at full strength strikes the nearest foe -- so a priest becomes a damage dealer, and the company's
-- ability to stay standing is cut in two for it.
--
-- PAID ON MERCY ACTUALLY NEEDED: the strike is measured against the patient's room to heal, so a heal
-- thrown at a full bar strikes nothing (models/combat.lua's Combat.titheRoom). Cast heals only -- an
-- ability or a draught -- never a standing Regeneration. The strike is unmitigated, answered by
-- nothing, and never lands on a body an objective names as its charge.
--
-- THE RULE FIRES ONCE (the half); the ladder is the strike: 100%, then 150%, then 200%.
return {
    name = "The Mirror Tithe",
    blurb = "Every heal the company casts also strikes the nearest foe for %d%% of what it would restore.",
    tier = "rare", mark = "Mt",
    cost = "The company's heals land at 50%.",
    scale = { 100, 50 },
    rules = { mirrorTithe = true },
    ruleScale = { mirrorTithe = { 1, 0.5 } },
}
