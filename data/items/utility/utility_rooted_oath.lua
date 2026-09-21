-- THE ROOTED OATH: the wearer does not move, and reaches further for it.
--
-- WAS A RUN RELIC (`relic_rooted_oath`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- THE CONVERSION THIS WHOLE MOVE IS BEST ILLUSTRATED BY. As a relic it rooted the COMPANY, which made
-- every escort and control-point objective unsatisfiable and left the honest answer as "the relic is
-- refused on those maps". One rooted body among four is a gun emplacement: the other three still walk
-- the ground, and where you set this one down at deployment is the decision.
--
-- `noMove` blocks the WALK and never ability-driven movement -- a shove, a blink or a charge still
-- moves the body, which is what keeps the rule a stance rather than a cage.
--
-- A UTILITY RATHER THAN ARMOUR. It was drafted as greaves and the type would not hold: armour's
-- contract (tests/armor_spec.lua) is a square of pace bought back with defense, and this pays not one
-- square but ALL of them and returns reach instead of guard. The flavor moved with the type -- a picket
-- driven into ground, not a leg harness -- because a name and an image are read as type claims here.
return {
    name = "The Rooted Oath",
    description = "You cannot move. Every ability reaches 3 tiles further, and deals 50% more damage.",
    flavor = "An iron picket, driven once and left. The company that set it did not come back for it.",
    sprite = "assets/items/rooted_oath.png",
    type = "utility",
    tags = { "trinket" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that marks a zone and holds it, which is what a body that cannot leave one does.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "warden",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: half again the damage and three tiles of reach, for a deployment decision rather than a turn cost.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.80,
    unlockLevel = 14,
    rules = { noMove = true, abilityRange = 3, damageMultiplier = 1.5 },
}
