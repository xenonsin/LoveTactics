-- WARDING ICON: the first blow of every fight lands on the ward instead.
--
-- WAS A RUN RELIC (`relic_warding_icon`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "Warding Icon",
    description = "Start each battle behind a barrier soaking 8 damage.",
    flavor = "Painted on a board thin enough to see the grain through. The face has been kissed almost flat.",
    sprite = "assets/items/warding_icon.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf whose whole mechanic is a standing ward over the party.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "paladin",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: a barrier soaking 8 is most of a blow, and it is there before anyone has acted.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    unlockLevel = 9,
    openingBoon = { id = "status_physical_barrier", opts = { magnitude = 8 } },
}
