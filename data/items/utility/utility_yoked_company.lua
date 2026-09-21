-- THE YOKED COMPANY: one bar for everybody, worn by one body.
--
-- WAS A RUN RELIC (`relic_yoked_company`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE ONE DOCUMENTED EXCEPTION TO THE BEARER RULE, and it is structural rather than a preference: a
-- shared health pool cannot be scoped to one body without ceasing to be the thing it is. So this item
-- is worn by one and felt by four, which is what a yoke is, and its description says so out loud --
-- see Combat.applyUnitRules, where the collective half and the per-bearer half are split.
--
-- IMPLEMENTED BY GIVING EVERY MEMBER THE SAME POOL rather than by redirecting reads: health is read in
-- something like forty places (mitigation, the bars, the AI's threat sums, the downed check, the
-- spoils screen) and a redirect would have to be right in all of them. One number, and every one of
-- those reads is already correct.
return {
    name = "The Yoked Company",
    description = "The whole company fights from one shared health pool, 15% larger than their maximums summed.",
    flavor = "A collar built for a team of four, and it has never been taken apart since it was made.",
    sprite = "assets/items/yoked_company.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that binds several things into one, which is the yoke.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "shaman",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: one pool 15% over the sum is a company that cannot be picked apart one body at a time.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.40,
    unlockLevel = 14,
    rules = { sharedPool = 15 },
}
