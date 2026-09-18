-- THE THIN BLADE: two gains bought with the run's own currency.
--
-- WAS A RUN RELIC (`relic_thin_blade`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE HEAVIEST TRADE ON THE UNCOMMON RUNG despite the smallest numbers, and the reason is which pool
-- the price comes out of: a lowered health CEILING is not given back by a camp, where a point of
-- defense is only ever missing during a fight.
return {
    name = "The Thin Blade",
    description = "Raises damage and skill by 2 each. Lowers maximum health by 8.",
    flavor = "Ground down over years of sharpening until there is more handle than steel, and it still parts cloth.",
    sprite = "assets/items/thin_blade.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that buys precision with a body it does not intend to have hit.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "assassin",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: two stats for a health ceiling no camp gives back, which is the heaviest price on the rung.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    dropTier = 6,
    bonus = { damage = 2, skill = 2 },
    maxBonus = { health = -8 },
}
