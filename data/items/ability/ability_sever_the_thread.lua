-- Sever the Thread: the Necromancer's cast twin of weapon_the_unreturning. A single dark bolt whose
-- KILL cuts the tie between a soul and its body, so the felled unit never opens the downed window --
-- no INCAPACITATED count, no Revive, no scroll, no Reviving Salts. It is a corpse the instant it drops,
-- exactly the way a demon's death skips the window (Combat.killUnit / status_downed).
--
-- Where the wand is a ranged sidearm that severs on every kill it happens to make, this is the
-- deliberate, dearer cut: longer reach, a heavier bolt, and the mana to say you MEANT it. The payoff is
-- the same and it is the discipline's whole thesis -- a normal kill leaves an incapacitated body Raise
-- Dead and Corpse Burst cannot touch for ~3 turns; this one leaves a corpse raisable on your next turn.
-- Sever with this, raise with that.
--
-- The severing rides on `opts.denyRevival`, folded INTO the bolt so it fires only on the KILL: a bolt
-- that merely wounds does nothing (it is the death that is final, not the hit), and against a foe that
-- was never revivable anyway (a demon) it is simply a heavy dark bolt.
--
-- Quest-only cut of the mage shelf: `discipline = "necromancer"`.
local Curve = require("models.curve")

return {
    name = "Sever the Thread",
    description = "Fires a dark bolt; a foe it kills leaves a corpse at once and can never be revived this battle.",
    flavor = "There is a thread. The Arcanum teaches which one, and then teaches that it is only a thread.",
    sprite = "assets/items/ability_sever_the_thread.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "mage",
    discipline = "necromancer",
    price = 320,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 6,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 15 },
        damage = Curve.ramp(9, 24), -- heavier than the wand's bolt: the deliberate cut
        effect = function(fx)
            -- Honoured only on the fatal path (Combat.dealFlatDamage): the kill severs the revive
            -- window; a wound leaves it open.
            fx.damage(fx.target, { denyRevival = true })
        end,
    },
}
