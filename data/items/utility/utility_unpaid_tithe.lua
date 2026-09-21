-- THE UNPAID TITHE: half again the damage, and nothing ever given back.
--
-- WAS A RUN RELIC (`relic_unpaid_tithe`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE GAG IS ENFORCED AT THE HELPER, not here (models/item_hook.lua's ctx.restore): every between-fight
-- restore asks the RECEIVING body's rules, so a larder on a tithed knight pays 0 and says nothing while
-- it still feeds the other three. That is the per-bearer reading of a rule that used to silence the
-- whole company's recovery at once.
return {
    name = "The Unpaid Tithe",
    description = "Deal 50% more damage. You recover nothing between fights.",
    flavor = "A receipt for a sum nobody in the company can read, stamped twice and never settled.",
    sprite = "assets/items/unpaid_tithe.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that strips what a target was given, turned on its own bearer.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "inquisitor",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: half again the damage on every swing, against attrition answered out of the grid.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.40,
    unlockLevel = 14,
    rules = { noRecovery = true, damageMultiplier = 1.5 },
}
