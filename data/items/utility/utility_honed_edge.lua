-- HONED EDGE: a whetstone kept to the blade, so the first swing is the best one.
--
-- WAS A RUN RELIC (`relic_honed_edge`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- IT USED TO BE MINTED AT A CAMP. The relic was the Rest's Sharpen verb -- an hour and a whetstone
-- bought a stacking grant -- and it was the one relic with `weight = 0`, never dealt by a floor. The
-- verb is cut with the shelf (states/game.lua, ui/panels/rest_choice.lua): a camp cannot conjure gear.
-- What it costs to have this now is a drop, like every other found thing.
return {
    name = "Honed Edge",
    description = "Start each battle Emboldened.",
    flavor = "A palm-sized stone, dished in the middle from forty years of the same stroke.",
    sprite = "assets/items/honed_edge.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf about opening a hole in the line, and this is the opening swing.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "vanguard",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: Emboldened for the opening exchange, which is the exchange that sets the trade.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    unlockLevel = 6,
    openingBoon = { id = "status_heroism", opts = { duration = 3 } },
}
