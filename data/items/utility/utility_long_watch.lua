-- THE LONG WATCH: the wearer opens every fight already mending.
--
-- WAS A RUN RELIC (`relic_long_watch`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "The Long Watch",
    description = "Start each battle with Regen.",
    flavor = "A sentry's token, passed along the wall at each change. Nobody remembers who is owed it back.",
    sprite = "assets/items/long_watch.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that brews restoratives, which is what a Regen at the bell is.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "herbalist",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: Regen through the opening turns, when a body is most likely to be focused.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    unlockLevel = 6,
    openingBoon = { id = "status_regen", opts = { duration = 3 } },
}
