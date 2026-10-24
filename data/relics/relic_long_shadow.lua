-- RARE. A three-tile horizon around the company, both ways. Nothing can aim at it from more than three
-- tiles off -- archers and casters have to walk in -- and nothing it casts reaches past three either.
--
-- BINDS THE AI AS IT BINDS THE PLAYER: the horizon is asked at the door the Shadow Mantle uses
-- (models/status.lua's Status.concealedAt), which the model's refusal, the target list and the
-- planner's stand-tile search all read -- so an enemy plans to close the gap rather than plan a shot it
-- cannot take. It is a rule, not a concealment: no light overrules it. An area cast centred elsewhere
-- still catches the company, because being caught is not being aimed at.
--
-- THE RULE FIRES ONCE; THE LADDER IS ARMOUR: +2 defense, +2 per further copy.
return {
    name = "The Long Shadow",
    blurb = "Nothing aims at the company from beyond 3 tiles. +%d defense.",
    tier = "rare", mark = "Ls",
    cost = "The company's own abilities reach 3 tiles at most.",
    scale = { 2, 2 },
    bonus = { defense = 2 },
    bonusStep = { defense = 2 },
    rules = { longShadow = true },
    ruleScale = { longShadow = { 3, 0 } },
}
