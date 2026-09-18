-- THE QUICK DRAW: sooner to act, and winded sooner for it.
--
-- WAS A RUN RELIC (`relic_quick_draw`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "The Quick Draw",
    description = "Raises speed by 3. Every ability costs 2 more stamina.",
    flavor = "A harness cut so nothing catches on the way out. It was cut for somebody else's ribs.",
    sprite = "assets/items/quick_draw.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf built on acting before the answer lands, and on stamina to do it.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "ninja",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: three speed is real tempo; the stamina surcharge is what keeps it honest.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    dropTier = 6,
    bonus = { speed = 3 },
    rules = { staminaSurcharge = 2 },
}
