-- THE BARED NERVE: proof against the unseen, open to the blade.
--
-- WAS A RUN RELIC (`relic_bared_nerve`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "The Bared Nerve",
    description = "Raises magic defense by 5. Lowers defense by 4.",
    flavor = "A wire of something pale, wound twice round the wrist and knotted where the pulse is.",
    sprite = "assets/items/bared_nerve.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that walks into casters, which is what buying magic defense with armour is for.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "spellbreaker",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: trades the blade's guard for the spell's, so the answer depends on the ground ahead.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 10,
    bonus = { magicDefense = 5, defense = -4 },
}
