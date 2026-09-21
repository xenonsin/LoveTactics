-- THE HELD LINE: hold formation, and be punished for leaving it.
--
-- WAS A RUN RELIC (`relic_standing_order`, uncommon tier) until the relic shelf was parked on
-- 2026-09-17; see models/relic.lua's park note for the whole move. The effect is unchanged in kind and
-- RESCOPED: a relic was held by the run and felt by the whole company, and this is worn by one body and
-- felt by that body.
--
-- RENAMED, BECAUSE "The Standing Order" IS ALREADY TAKEN by an unrelated item.
-- `utility_standing_order` is the artificer's signature -- an unlock-gated active that upgrades every
-- construct standing -- and it shares nothing with this but the words. Two blueprints under one display
-- name is how a corpus grows a claim nobody can trace, so this one moved rather than the signature.
--
-- THE NAME IS PROVISIONAL and is mine rather than the author's. "The Held Line" keeps the formation
-- reading and the definite article the relic had; a better one costs an id sweep plus this header.
--
-- BOTH HALVES ARE TRAITS, which items already carry -- the gain while a neighbour stands there, and the
-- penalty while none does. Kept as the authored pair rather than folded into one reflex: the trade is
-- the item, and a single trait would have hidden half of it.
return {
    name = "The Held Line",
    description = "Raises defense by 3 while an ally is adjacent. Lowers it by 3 while none is.",
    flavor = "Written out, countersigned, and folded to the size of a palm. It has not changed in eleven years.",
    sprite = "assets/items/held_line.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that stands beside an ally on purpose.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "sentinel",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: three defense for standing where you were told, and three against for leaving.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 10,
    traits = { "trait_formation_fighter", "trait_standing_order_alone" },
}
