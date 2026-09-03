-- Quietus: a dagger, so it owes the family contract (docs/weapons.md) -- quick, and it opens a wound
-- (Bleed). What it adds over data/items/weapon/weapon_iron_dagger.lua is the assassin's whole creed
-- made mechanical: a foe it KILLS stays killed. The felling stab severs the tie to life, so the body
-- never opens the downed window every other death gives -- it does not lie there INCAPACITATED with a
-- count over it waiting for a Revive, a scroll, or Reviving Salts. It is a corpse the instant it drops,
-- exactly the way a demon's death skips the window (Combat.killUnit / status_downed). No revive this
-- battle, for anyone.
--
-- The severing rides on `opts.denyRevival`, folded INTO the stab so it fires only on the KILL: a stab
-- that merely wounds does nothing but bleed, which is correct -- it is the death that is final, not the
-- hit. Against a foe that could never be revived anyway (a demon) it is simply a plain dagger.
--
-- It is the blade twin of the necromancer's severing bolt (weapon_the_unreturning), the same finality
-- said in the other sin's voice: the Arcanum severs to keep the corpse for itself; the Undercroft
-- severs so a paid-for death cannot be undone. And it reads DIRECTLY into the assassin's own execute
-- (data/items/ability/ability_coup_de_grace.lua) -- the Coup finishes the wounded and this makes the
-- finish permanent, so an assassin carrying both closes the contract and seals it in one turn.
--
-- Quest-only cut of the rogue shelf: `class = "assassin"`, buyable only once the assassin gate is
-- cleared.
local Curve = require("models.curve")

return {
    name = "Quietus",
    description = "Inflicts Bleed. A foe it kills cannot be revived this battle. It leaves a corpse at once, not a downed body.",
    flavor = "The Undercroft prices two things separately: the death, and the guarantee it stays one.",
    sprite = "assets/items/quietus.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "assassin",
    price = 660,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, as every dagger is (docs/weapons.md)
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(13, 23),
        effect = function(fx)
            -- Bleed lands on a survivor (opts.inflicts, the family's wound); denyRevival lands only on
            -- the KILL (opts.denyRevival -> Combat.dealFlatDamage's fatal branch). One stab, both.
            fx.damage(fx.target, { inflicts = "status_bleed", denyRevival = true })
        end,
    },
}
