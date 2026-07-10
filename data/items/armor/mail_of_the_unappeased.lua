-- Lifted off Ira's body, and it kept her rule. `traits` on an item reach whoever carries it in their
-- 3x3 grid (models/trait.lua): every hit the wearer walks away from is added to their next blow. You
-- fought that mechanic; now you are it. That is the payment for a general, and the shape every one of
-- the seven relics takes -- kill a sin, wear it.
--
-- It is a trap dressed as a reward, exactly as it was when she wore it. The rage only pays out if you
-- are being hit, and armor this thin means you will be.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
--
-- The description carries the first of seven fragments naming the Gate Below. The Gate itself is
-- keyed off the QUEST you finished, never off this item (see questGate in models/quest.lua) -- so
-- stashing it, wearing it, or losing it can never cost you the endgame.
return {
    name = "Mail of the Unappeased",
    description = "Ira's mail, still warm. Every wound you survive is added to your next blow. " ..
        "Scratched inside the collar: \"beneath the sand, where the roaring was loudest\".",
    sprite = "assets/items/mail_of_the_unappeased.png",
    type = "armor",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "wrath_rising" },
    -- Light for a chestpiece. She never needed the steel, and neither will you if you win fast.
    bonus = { defense = 4, movement = 0 },
    resist = { slash = 2 },
}
