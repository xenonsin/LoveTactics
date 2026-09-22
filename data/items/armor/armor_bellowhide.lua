-- BELLOWHIDE: the print you meet. The shallowest of the Ancient Stag's three, and the one that is
-- simply the animal, tanned.
--
-- WHAT MAKES IT WORTH A SLOT IS THE RESIST LINE, and it is half of the blueprint's own line worn by a
-- person. data/characters/character_stag_beast.lua carries `impact = 3, pierce = -3` and argues it in
-- two sentences: hide stretched over a frame built to take a rival's charge head-on, every autumn, for
-- years -- and built to take it from the FRONT, so a point that does not come from the front finds a
-- lean animal.
--
-- IT KEEPS THE IMPACT AND NOT THE HOLE, and that is a rule rather than a choice -- the same one
-- data/items/armor/armor_bristlehide.lua obeys and states. A CREATURE's three physical lines must sum
-- to zero (docs/bestiary.md): the negative is the price that buys the positive, and it is a fact about
-- a body nobody chose. A coat plays by different rules. `armor_reckless_cuirass` and the Bristlehide
-- are the only wearable negative resists in the game and tests/armor_spec.lua pins them there BY NAME,
-- because a negative resist amplifies the hit and a player who picks a coat up mid-run should not be
-- quietly handed one. So the trade stays on the animal, and what comes off it is the half you can
-- actually wear.
--
-- AGAINST THE BOAR'S, which is the comparison a player will actually make, since the Bristlehide is
-- the other beast hide on the shelf and sits a rung shallower. Bristle over fat answers the BLADE; this
-- answers WEIGHT. Between them the two commonest animals on the road cover opposite corners of the
-- melee triangle, so which beast you went hunting is a question about what the floor ahead is carrying.
-- A hair deeper than the Bristlehide, and only because it carries no negative of its own to pay with.
--
-- Every armour costs a square of pace (docs/classes.md, pinned by tests/armor_spec.lua) -- the defense
-- and the resist are what buy it back.
--
-- No trait and no rule. It is a coat, it is the first thing this animal pays, and a rule on it would be
-- spending the stag's second and third drops early.
--
-- RIFT-ONLY (`unstocked`). It comes off the body and nowhere else: no counter deals one however many
-- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
local Curve = require("models.curve")

return {
    name = "Bellowhide",
    description = "Blunts weight.",
    flavor = "Cut from the shoulders, where every autumn of its life is stacked up in layers.",
    sprite = "assets/items/armor_bellowhide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    -- The first of three by depth, which is this system's rarity (docs/drops.md): the hide is the
    -- print you meet, the Close Herd is the rule, and the Lowered Crown is the one you are still after.
    unlockLevel = 2,
    unstocked = true,
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
    -- The animal's own line, minus the price. See the header on why the hole stays on the stag.
    resist = { impact = 3 },
}
