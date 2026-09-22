-- DUELIST'S SPUR: the wearer starts every fight already moving.
--
-- WAS A RUN RELIC (`relic_duelists_spur`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- AN OPENING BOON (`openingBoon`), applied to the bearer by states/battle.lua once the units are
-- built. Read off the grid rather than queued by a run, so it works in every fight however it was
-- entered -- a campaign battle, a descent stop, the arena -- which the relic it came from could not.
return {
    name = "Duelist's Spur",
    description = "Start each battle Hasted.",
    flavor = "Blunt, and worn on the heel of the boot that leads. A duellist who waits for the bell has lost a step.",
    sprite = "assets/items/duelists_spur.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf built on holding a stance against one foe, which opening Hasted is the start of.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "duelist",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: Hasted from the first turn, when the board is still being decided.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    unlockLevel = 9,
    openingBoon = { id = "status_hasted", opts = { duration = 3 } },
}
