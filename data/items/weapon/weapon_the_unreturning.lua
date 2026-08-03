-- The Unreturning: a wand, so it is ranged magical and needs only a direction -- no minRange, just
-- sight down the line (docs/weapons.md, the wand family's whole claim over a bow). Its bolt is `dark`,
-- and its extra is what the Arcanum's inner circle actually built it for: a KILLING bolt severs the
-- thread that ties a soul to its body, so the felled unit never gets the downed window every other
-- death opens. It does not lie there INCAPACITATED with a count over it, waiting for a Revive, a scroll,
-- or Reviving Salts -- it is a corpse at once, exactly the way a demon's death skips the window (see
-- Combat.killUnit / status_downed). No revive this battle, for anyone.
--
-- That is the read the discipline is built on, and why the finality is the PAYOFF rather than a cruelty
-- for its own sake: a normal kill hands the necromancer an incapacitated body that Raise Dead and
-- Corpse Burst cannot touch for ~3 turns (they read `corpse`, which the downed window has not set yet).
-- This bolt hands them a harvestable body NOW. It severs the enemy's road back and opens your own in the
-- same motion -- kill with the wand, raise with the staff on the very next turn.
--
-- The severing rides on `opts.denyRevival`, folded INTO the bolt so it only fires on the KILL: a bolt
-- that merely wounds does nothing at all, which is correct -- it is the death that is final, not the
-- hit. On a foe that could never be revived anyway (a demon) it is simply a plain dark bolt.
--
-- Quest-only cut of the mage shelf: `discipline = "necromancer"`, buyable only once the necromancer
-- gate is cleared.
local Curve = require("models.curve")

return {
    name = "The Unreturning",
    description = "Fires a dark bolt; a foe it kills leaves a corpse at once and cannot be revived this battle.",
    flavor = "The Arcanum does not call it cruel. It calls it tidy: a death that files itself.",
    sprite = "assets/items/the_unreturning.png",
    type = "weapon",
    tags = { "wand", "dark", "magical" }, -- magical: routes through magicDamage / magicDefense
    class = "mage",
    discipline = "necromancer",
    price = 460,
    unlockQuests = 10,
    activeAbility = {
        target = "enemy",
        range = 5,
        requiresSight = true, -- a wand needs only a direction (no minRange), but it must SEE down the line
        speed = 5,
        cost = { stat = "mana", amount = 12 },
        damage = Curve.ramp(9, 19), -- power + the wielder's Magic Damage, minus Magic Defense
        effect = function(fx)
            -- denyRevival rides on the bolt and is honoured only on the fatal path (Combat.dealFlatDamage):
            -- a kill severs the revive window, a mere wound does nothing.
            fx.damage(fx.target, { denyRevival = true })
        end,
    },
}
