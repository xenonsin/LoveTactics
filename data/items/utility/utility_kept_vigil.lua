-- THE KEPT VIGIL: blessed going in, and topped up coming out.
--
-- WAS A RUN RELIC (`relic_kept_vigil`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE ONE ITEM THAT USES BOTH NEW SEAMS AT ONCE -- an `openingBoon` for the half that lands at the
-- bell and an `encounterCleared` hook for the half that pays on the way out. Kept together rather than
-- split into two items because the relic's whole argument was that they are one observance.
return {
    name = "The Kept Vigil",
    description = "Start each battle Blessed. Recover 4 mana after every fight you clear on an expedition.",
    flavor = "A stub of candle and a slip of paper with a name on it. Both get replaced. The keeping does not.",
    sprite = "assets/items/kept_vigil.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that holds a holy cast and pays in mana, both halves of this observance.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "theurge",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: two gifts in one: a Blessing at the bell and mana back at every stop.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    dropTier = 4,
    openingBoon = { id = "status_blessing" },
    encounterCleared = function(_, ctx)
        local given = ctx.restore(ctx.char, "mana", 4)
        if given > 0 then ctx.say("The Kept Vigil  +" .. given .. " mana") end
    end,
}
