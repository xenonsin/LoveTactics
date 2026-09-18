-- THE LONG WAIT: two acts at a time, at half the tempo.
--
-- WAS A RUN RELIC (`relic_long_wait`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- AUTHORED IN INITIATIVE, NOT IN ROUNDS. The spec for this was "acts every other round" and there are
-- no rounds -- combat is an initiative countdown -- so the price is a flat 2x `initiativeCost` against
-- a `burstActions` of 2. Letting the price emerge from the tempo debt instead was a perfect wash (two
-- actions for exactly two turns of tempo), which bought nothing at all.
return {
    name = "The Long Wait",
    description = "Take 2 actions on your turn. Every turn costs twice the initiative.",
    flavor = "An hourglass with no stand, so somebody has to hold it, and holding it is the whole job.",
    sprite = "assets/items/long_wait.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that plants and then picks its moment, which is what a doubled turn at half tempo is.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "saboteur",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: two actions a turn is the largest thing a body can be given; the tempo price is severe and still worth it.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.80,
    dropTier = 8,
    rules = { burstActions = 2, initiativeCost = 2 },
}
