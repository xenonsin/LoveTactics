-- WINTERHIDE: the sow's coat, and the piece you meet. The bear's answer to armor_bristlehide.
--
-- The two hides are the same object at two animals, and their resist lines are the argument. A boar is
-- bristle over a hand's depth of fat, so it turns a blade and folds to a mace. A bear is DEPTH -- a point
-- goes in and is still going in and finds nothing that matters -- so what this coat turns is the spear,
-- and it is the only hide on the shelf that does. Nothing else in the hunter's rack answers pierce.
--
-- IT KEEPS THE POSITIVE HALF AND NOT THE NEGATIVE ONE, which is a rule rather than a softening. The
-- animal's own line is `pierce +4 / slash -4` (character_sow.lua) because a creature's innate hide is a
-- REDISTRIBUTION and must sum to zero; a coat is not, and tests/armor_spec.lua holds that exactly one
-- armour in the game sells a negative resist. So the weakness stays on the bear and does not come off it
-- with the skin. What the wearer pays instead is the square of pace every armour costs.
--
-- SHALLOW ON PURPOSE, and for Bristlehide's own reason one animal up. The road bear is met from day two
-- (encounter_bear) and a floor only pays the ranks it reaches (Spoils.rankBand), so a deep tier on a
-- common animal is an item nobody sees until the animal has stopped being interesting. It sits one rung
-- over the boar's hide because the animal is one rung harder, and under both of her other pieces because
-- it is the one you are meant to actually find.
local Curve = require("models.curve")

return {
    name = "Winterhide",
    description = "Turns a point. There was never a great deal it could do about an edge.",
    flavor = "Four winters of everything in the wood trying, and a fifth that finally managed it.",
    sprite = "assets/items/armor_winterhide.png",
    type = "armor",
    tags = { "hide" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, and with its own sibling: Bristlehide is the
    -- hunter's too. `class` is the vendor shelf and never an equip gate -- anyone may carry it.
    class = "hunter",
    unlockLevel = 3,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    -- Every armour costs a square of pace (docs/classes.md, pinned by tests/armor_spec.lua) -- the
    -- defense and the resist are what buy it back.
    bonus = { defense = Curve.ramp(3, 14), movement = -1 },
    resist = { pierce = 4 },
}
