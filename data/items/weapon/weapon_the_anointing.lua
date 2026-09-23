-- THE ANOINTING: the Lust circle's first verb, fielded at last by something a floor can actually roll.
--
-- `Descent.SINS` lists five verbs for this stratum and CHARM is the first of them -- "you do not choose
-- whose side you are on" -- and until this body arrived nothing rollable on the castle delivered it.
-- The Suppliant's petal touch charms, but she is SEATED (Descent.SINS' `minor.lead`): she stands on one
-- landing, once, at the end of the circle. So the circle's headline rule, and the counterplay its own
-- header spends a paragraph on (cut the charmer and everyone she holds comes back, mid-turn --
-- Combat.releaseCharmedBy), existed in prose and in no fight a company could meet twice.
--
-- SHE DOES NOT MOVE YOU AND SHE DOES NOT CALL YOU. The flock decides where your body is; the Matriarch
-- decides what it does; this decides WHOSE IT IS. Everything else on this ground bills position. This
-- bills allegiance, which is the one thing on the list that cannot be answered by standing somewhere
-- sensible.
--
-- THE ROLL IS THE SOFTENING CURVE, AND IT IS NOT COPIED HERE. Status.charmChance owns it -- 25% against
-- a whole body, up to 85% against one nearly down -- and ability_charm reads the same function. Two
-- deliverers with two copies of `25 + (1 - frac) * 60` is a number that drifts the first time anybody
-- tunes it, and the tuning would then only land on whichever of them the tuner had open. What this file
-- still owns is whether to roll at all and what it says when the roll fails.
--
-- WHICH MAKES THE COUNTERPLAY A HEALTH BAR RATHER THAN A DICE READ. A company that holds its line
-- whole walks through most of her casts; a company that has been ground down by a floor of harpies and
-- coils hands her a body on the first ask. That is the right shape for an elite seated on the second
-- half of a stratum -- she is not the fight, she is what the rest of the floor was setting up.
--
-- DARK AND MAGICAL, NOT FIRE. Fire at reach belongs to the Matriarch's cry on this ground
-- (weapon_the_wanting) and a second burning ranged blow would make the two alphas one alpha at two
-- volumes. The channel is `magical` for the same reason hers is: this circle otherwise runs entirely on
-- armour, and a party in plate should not be able to walk the whole stratum without ever reading a
-- resist line.
--
-- THE CHARM IS GATED ON THE HIT. A rider that could not miss riding a blow that could is the shape of
-- bug this whole circle was rebuilt out of once already (docs/accuracy.md).
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "The Anointing",
    description = "Strikes a distant foe and inflicts Charm, likelier the more wounded it is.",
    flavor = "The rite is the same one they use on the children. She only ever changed whose name it ends on.",
    sprite = "assets/items/the_anointing.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "dark", "magical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 10 },
        damage = Curve.ramp(4, 14), -- the blow is an excuse; the rider is the cast (span 10: Curve.LEVELS - 1)
        effect = function(fx)
            local dealt = fx.damage(fx.target)
            if dealt <= 0 or not fx.target.alive then return end
            -- The shared curve, not a second copy of it (see the header, and Status.charmChance).
            if fx.random(100) <= Status.charmChance(fx.target) then
                -- She rides along as the status's `applier`, which is how the flip knows whose side the
                -- body now stands on -- and how the release knows whom to hand it back from when she
                -- falls (data/status/status_charm.lua).
                fx.applyStatus(fx.target, "status_charm")
            else
                fx.log("action", string.format("%s will not answer to it.",
                    (fx.target.char and fx.target.char.name) or "The target"))
            end
        end,
    },
}
