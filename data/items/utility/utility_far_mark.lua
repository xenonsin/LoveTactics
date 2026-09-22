-- THE FAR MARK: every reach lengthens, and nothing close is worth hitting.
--
-- WAS A RUN RELIC (`relic_far_mark`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- TWO RULES (Item.RULE_NAMES), which is the vocabulary the parked shelf's rare tier ran on: the reach
-- and the contact penalty are read by Combat.abilityRange and Combat.flatStat respectively. The only
-- uncommon that rewrites a rule at all, which is why it converted as one rather than as flat stats.
return {
    name = "The Far Mark",
    description = "Every ability reaches 1 tile further. Lowers damage by 3 against adjacent foes.",
    flavor = "A ranging stick notched at distances that match no bow in the company.",
    sprite = "assets/items/far_mark.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf whose identity is range, and which never wanted to be adjacent anyway.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "bombardier",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: a tile of reach on EVERY ability, paid for only where the bearer did not want to be.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 12,
    rules = { abilityRange = 1, contactPenalty = 3 },
}
