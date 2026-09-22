-- GLUTTON'S PURSE: it doubles what a fight pays, and it is heavy.
--
-- WAS A RUN RELIC (`relic_gluttons_purse`, common tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE PRICE MOVED FROM THE BELL TO THE CEILING, and this is the one conversion on the shelf whose cost
-- is not the same quantity it was. The relic drained 4 stamina from everyone at the opening bell --
-- reachable because a relic had a `battleStart` hook to spend it from. An item has no such seam, and
-- inventing one for a single cost would have been a mechanic built for one blueprint. A lowered
-- stamina CEILING is the same toll paid in the existing vocabulary: felt from the first turn, felt
-- every fight, and legible on the row the tooltip already prints.
--
-- The gold half is unchanged, and it is the reason this is gear rather than bookkeeping: what it pays
-- lands in the purse the company spends at the next stop.
return {
    name = "Glutton's Purse",
    description = "Doubles the gold from every fight you clear on an expedition, and pays at least 6.",
    flavor = "Sewn from something with a grain to it, and it has never once been full.",
    sprite = "assets/items/gluttons_purse.png",
    type = "utility",
    tags = { "pack" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the one shelf that spends gold as a combat resource, so a purse that doubles takings feeds it directly.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "mammonite",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: doubled takings compound over a run; the stamina ceiling is the price.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.45,
    unlockLevel = 9,
    maxBonus = { stamina = -4 },
    encounterCleared = function(_, ctx)
        local base = (ctx.spoils and ctx.spoils.gold) or 10
        local bonus = math.max(6, math.floor(base))
        ctx.addGold(bonus)
        ctx.say("Glutton's Purse  +" .. bonus .. "g")
    end,
}
