-- THE KEEN EDGE: three points of damage for three points of guard.
--
-- WAS A RUN RELIC (`relic_keen_edge`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE PLAINEST TRADE ON THE SHELF, and the line the others are measured against. Mitigation here is
-- subtractive, so a point of damage and a point of defense are the same quantity moving in opposite
-- directions: +3 / -3 is a wash on paper and a real decision in practice, because you take it knowing
-- whether the ground ahead hits once hard or many times lightly.
return {
    name = "The Keen Edge",
    description = "Raises damage by 3. Lowers defense by 3.",
    flavor = "A strop and a tin of green paste, and a habit of walking off to use them before anyone sits down.",
    sprite = "assets/items/keen_edge.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that already trades its own safety for damage.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "barbarian",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: the plainest trade on the shelf: three damage for three guard, and a wash on paper.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 10,
    bonus = { damage = 3, defense = -3 },
}
