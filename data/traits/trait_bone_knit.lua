-- BONE-KNIT: the rule that makes a skeleton a skeleton, stated from the side that is an upside.
--
-- The bearer does not stop when it is killed. A blow that would drop it is met by paying mana -- the
-- light still in the marrow -- and the body assembles itself where it fell, WHOLE. As often as it can
-- pay for, which is the whole of the mechanic: there is no charge, no cooldown and no once-a-battle
-- latch. What ends it is an empty pool.
--
-- A PURE MARKER WITH NO HOOKS, exactly like data/traits/trait_second_wind.lua and for the same reason:
-- the rule lives in the damage core (Trait.trySurvive, consulted by Combat.dealFlatDamage the moment a
-- hit reaches 0 HP), so anything that grants a refusal to fall refuses identically. What this file adds
-- over Second Wind is a `cost`, and in that function a cost REPLACES the latch rather than joining it --
-- see its header on the two things that can bound a refusal. So this is not Second Wind made cheaper or
-- Second Wind made repeatable; it is the other of the two shapes.
--
-- WHY THE WHOLE BAR, which is the decision the rest of this file is downstream of. It arrives on the
-- same item as Grave-Cold (data/traits/trait_grave_cold.lua), so the body wearing it cannot be healed
-- BY ANYTHING -- not a priest, not a draught, not a sanctified zone, not a night at the Ward. Rise it at
-- a sliver and the sliver is what it keeps for the rest of the fight, and the aspect collapses into a
-- slower way of dying. Rise it whole and the loop closes on itself, which is the good version:
--
--     DYING IS THE ONLY WAY A SKELETON HEALS, AND IT IS PRICED IN MANA.
--
-- That is one rule doing the work of two, it is legible the first time it happens to you, and it makes
-- every point of chip damage a question -- do I spend forty to clear it, or hold the pool and hope?
-- Nothing else in the game asks that, and it could not be asked at a quarter of a bar.
--
-- WHY MANA, AND WHY FORTY. Mana does not regenerate mid-fight in this game
-- (data/items/utility/utility_wellspring_sandals.lua makes the point at length), so the pool a body
-- walks in with is every death it gets to refuse, and every spell it casts is one of them spent. Forty
-- is deliberately more than the most expensive spell in the catalogue (thirty): a full bar back is the
-- largest single thing any effect in this game does, and it must never be the cheap option on a caster's
-- turn. A deep pool buys two of these and no spells; a shallow one buys none until its bearer goes and
-- builds for it, which is a synergy the player assembles rather than a rung the item hands out.
return {
    name = "Bone-Knit",
    description = "Consume 40 mana when a blow would fell this body, and it stands back up at full health.",
    revivesOnLethal = true, -- read by Trait.trySurvive (models/trait.lua) at the death threshold
    -- THE WHOLE BAR. A granter may still name its own share -- the Cafe's Empty Chair rises at a sliver
    -- off the same engine seam -- but this one is 1.0 on the argument above, not for want of a figure.
    revivesAt = 1.0,
    -- THE TOLL, and what stands in for the once-per-battle latch every other refusal carries. A granting
    -- item may name its own through `traitParams.cost` (models/trait.lua's Trait.param), which is how a
    -- lesser body gets a cheaper death without a second copy of this file.
    cost = { stat = "mana", amount = 40 },
    revivesLine = "%s gathers itself back together, whole!",
}
