-- BRISTLEHIDE: a boar's own answer to being hit, cut off it and worn.
--
-- Bristle over a hand's depth of fat, which is what character_boar.lua's innate line says it is for --
-- an armour's `resist` and a body's innate line are written in the same unit and folded into the same
-- total (models/character.lua), so this is literally the animal's own mitigation moved onto a person.
--
-- IT KEEPS THE SLASH AND NOT THE HOLE, and that was a rule rather than a choice. The boar's own line is
-- `slash 4, impact -4` -- the fat turns a blade and does nothing whatever about a mace, and the negative
-- is the price that buys the positive (docs/bestiary.md: the three physical lines on a CREATURE must sum
-- to zero). A coat plays by different rules. `armor_reckless_cuirass` is the only wearable negative
-- resist in the game and tests/armor_spec.lua pins it there by name, because a negative resist amplifies
-- the hit and a player who picks a coat up mid-run should not be quietly handed one. So the trade stays
-- on the animal, where it is a fact about a body nobody chose, and what comes off it is the half you can
-- actually wear.
--
-- Shallow on purpose. It drops off the commonest animal in the game, so it is most players' first piece
-- of TAGGED mitigation rather than another flat defense number -- three points of slash is most of a
-- good coat's worth against one weapon and nothing at all against the rest (docs/vulnerability.md), and
-- learning that is the item's real job.
local Curve = require("models.curve")

return {
    name = "Bristlehide",
    description = "Turns a blade. It was never going to help with a mace.",
    flavor = "The Warren will not stitch it. They will, for a fee, tell you which way round it goes.",
    sprite = "assets/items/armor_bristlehide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    -- SHALLOW, and it has to be: it drops off a day-one body (character_boar), and a floor only pays
    -- ranks it reaches (Spoils.rankBand). A deep tier on the commonest animal in the game is an item
    -- nobody meets until the animal has stopped being interesting.
    unlockLevel = 2,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    -- Every armour costs a square of pace (docs/classes.md, pinned by tests/armor_spec.lua) -- the
    -- defense and the resist are what buy it back.
    bonus = { defense = Curve.ramp(2, 12), movement = -1 },
    resist = { slash = 3 },
}
