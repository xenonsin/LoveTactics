-- THE WHETTED VOW: twice the blow for half the body.
--
-- WAS A RUN RELIC (`relic_whetted_vow`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- ONE NUMBER DOING TWO JOBS, declared twice on purpose: `halveMaxHealth` is the DIVISOR on the ceiling
-- and `damageMultiplier` the multiplier on the blow, and they are deliberately the same figure. An
-- implicit second reader would be a mechanic nobody could find. The multiplier composes with any other
-- source of one (Item.mergeRules multiplies); the divisor does not.
return {
    name = "The Whetted Vow",
    description = "Deal double damage. Halves your maximum health.",
    flavor = "A vow scratched into the flat of something and then scratched out, twice, in a different hand.",
    sprite = "assets/items/whetted_vow.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that swears for damage, and the vow this is named for.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "crusader",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: double damage is the largest multiplier in the game, and the halved body is a real wager.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.80,
    unlockLevel = 15,
    rules = { halveMaxHealth = 2, damageMultiplier = 2 },
}
