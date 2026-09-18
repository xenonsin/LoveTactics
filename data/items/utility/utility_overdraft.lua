-- THE OVERDRAFT: casting costs no mana and is paid in blood.
--
-- WAS A RUN RELIC (`relic_overdraft`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- FLOORED AT 1 BY THE ENGINE, not by this blueprint. Costs apply after `costBlock` and `spendResource`
-- does not floor health, so this could once kill its own caster without running killUnit at all. The
-- floor is the standing toll rule -- a price wounds, never fells -- and it lives in combat.
return {
    name = "The Overdraft",
    description = "Abilities cost no mana. Each cast takes that price in health instead.",
    flavor = "A tally board with two columns, and only one of them has ever been written in.",
    sprite = "assets/items/overdraft.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf already priced in bodies rather than in mana.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "necromancer",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: a caster with no mana ceiling at all, spending a pool that heals between fights.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.60,
    dropTier = 8,
    rules = { manaToHealth = 1.0 },
}
