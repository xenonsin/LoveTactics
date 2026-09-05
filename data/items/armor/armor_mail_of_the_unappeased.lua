-- Lifted off Ira's body, and it kept her rule. `traits` on an item reach whoever carries it in their
-- 3x3 grid (models/trait.lua): the nearer the wearer is to death, the harder they hit. You fought
-- that mechanic; now you are it. That is the payment for a general, and the shape every one of
-- the seven relics takes -- kill a sin, wear it.
--
-- It is a trap dressed as a reward, exactly as it was when she wore it. The payout only arrives when
-- you are nearly dead, and armor this thin means you will get there. It asks you to want what she
-- wanted, and what she wanted was a freedom the fight kept promising and never gave.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
--
-- The FLAVOR carries the first of seven fragments naming the Gate Below (docs/item-text.md: the
-- line is story, not a rule, and the tooltip prints it italic at the foot). The Gate itself is
-- keyed off the QUEST you finished, never off this item (see questGate in models/quest.lua) -- so
-- stashing it, wearing it, or losing it can never cost you the endgame.
local Curve = require("models.curve")

return {
    name = "Mail of the Unappeased",
    description = "Increase damage by 1 per blow you take, plus up to +20 by the fraction of health missing.",
    flavor = "Ira's mail, still warm. Scratched inside the collar: \"beneath the sand, where the " ..
        "roaring was loudest\".",
    sprite = "assets/items/mail_of_the_unappeased.png",
    type = "armor",
    class = "creature",
    dropTier = 7,
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_wrath_rising" },
    -- Light for a chestpiece. She never needed the steel, and neither will you if you win fast --
    -- but it is still mail, and mail costs a square like every other coat on the rack. There is no
    -- free tier to put a relic in (docs/classes.md).
    bonus = { defense = Curve.ramp(4, 14), movement = -1 },
    resist = { slash = 2 },
}
