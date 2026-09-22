-- THE DEEP LARDER: salted meat enough that clearing a room is a meal.
--
-- WAS A RUN RELIC (`relic_deep_larder`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE ONE ITEM SHAPE NOTHING ELSE IN THE GRID HAS: it acts BETWEEN fights, on the expedition, rather
-- than inside one. That is why models/item_hook.lua exists at all -- three pieces of gear need the run
-- loop to ask the roster a question, and this is the plainest of them.
--
-- FEEDS ITS CARRIER, not the company. As a relic it healed all four; a larder in one knight's pack
-- feeds the knight, and a company that wants to be fed four times carries four.
return {
    name = "The Deep Larder",
    description = "Recover 6 health after every fight you clear on an expedition.",
    flavor = "Salt, fat and a tight lid. It has outlasted three owners and shows no sign of having noticed.",
    sprite = "assets/items/deep_larder.png",
    type = "utility",
    tags = { "pack" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that treats the party between fights with doses.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "apothecary",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: a fight's worth of health back at every stop, which is a camp the company did not have to spend.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    unlockLevel = 9,
    encounterCleared = function(_, ctx)
        local given = ctx.restore(ctx.char, "health", 6)
        if given > 0 then ctx.say("The Deep Larder  +" .. given .. " health") end
    end,
}
