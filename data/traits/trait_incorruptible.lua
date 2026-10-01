-- INCORRUPTIBLE: the angel's racial rule, carried on its grant (data/items/utility/utility_angel_blood.lua).
-- Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- A FLAG AND NOTHING ELSE. The two walls it raises already exist and are asked in one place each: Status.isImmune
-- refuses a debuff whose applier is not of the bearer's side (the same seam a boss's Charm refusal and a bought
-- statusImmunity answer through, so the log, the tooltip and the blow agree), and Status.blocksForcedMove refuses
-- every shove, throw and drag, as the Oni Greatblade's Unmoved does.
return {
    name = "Incorruptible",
    description = "Debuffs from outside your side never land, and nothing pushes or pulls you.",
    incorruptible = true,
}
