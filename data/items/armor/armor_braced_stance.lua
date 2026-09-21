-- THE BRACED STANCE: heavier on the ground, and slower across it.
--
-- PLATE RATHER THAN `heavy`, and the tag is load-bearing: tests/armor_spec.lua charges the heavy tier
-- TWO squares of pace, and the relic this converts from priced itself at exactly one. Tagging it heavy
-- would have doubled an authored cost to satisfy a label.
--
-- WAS A RUN RELIC (`relic_braced_stance`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "The Braced Stance",
    description = "Raises defense by 4. Lowers movement by 1.",
    flavor = "Sabatons with a wide, flat tread, made for a line that is not expected to give.",
    sprite = "assets/items/braced_stance.png",
    type = "armor",
    tags = { "plate" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that holds ground and moves foes off it, paid for in pace.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "bulwark",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: four defense for a square of pace: a line that does not intend to move anyway.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 10,
    bonus = { defense = 4, movement = -1 },
}
