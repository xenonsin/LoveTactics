-- THE SECOND BITE: the pack's teeth, forged.
--
-- THE GAME'S FIRST BRAVE WEAPON. It strikes twice, always, for no condition at all -- Fire Emblem's
-- Brave Sword and its kin, which hit twice per attack and pay for it in weight and in Might. The rule
-- is `strikes = 2` on the ability below and it is honoured by every damage path at once (Item.strikes,
-- models/combat.lua); this file authors nothing of it but the count and the price.
--
-- IT USED TO ROLL FOR THE SECOND BITE AND NOW IT BUYS IT, and the distinction is worth keeping
-- straight because the wolves still roll. FE carries TWO ways to swing more than once -- the DOUBLING
-- rule, where enough attack speed over your target earns a follow-up, and the BRAVE weapon, which
-- simply always does. This blade shipped as the first: a +2 speed gap, read off the board at swing
-- time. That rule was never this weapon's to own -- weapon_wolf_fangs and weapon_white_wolf_fangs
-- carry it too and carry it better, since a wolf is a body with a speed stat and a knife is not. So
-- the doubling goes back to the pack, where it is a fact about the animal, and the knife keeps the
-- half a forged thing can actually promise: it does it every time.
--
-- WHAT IT COSTS, AND WHY THE CURVE CAME DOWN TO 7. A swing is `weapon damage + the wielder's attack
-- stat - the target's armour` (Combat.dealDamage), and the brave rule repeats the WHOLE of that, the
-- attack stat included. A rogue's attack stat is 15 and grows past 25, so at the old ladder-grade 15
-- this blade was landing two full blows of thirty -- not a strong knife, a doubled one. The damage
-- line is the only lever a blueprint holds over that, so it takes the whole cut: 7 is under the Iron
-- Dagger's own 5-to-15 opening, and the second strike is what is bought with the difference.
--
-- It is still, by construction, the hardest-hitting knife on the rack against soft bodies, and it is
-- MEANT to be -- this comes off the White Wolf and nothing else. What it is not is universally the
-- best, because armour is subtracted from EACH strike (Combat.mitigatedDamage runs per hit). Two
-- small bites lose twice to a plate coat where one big one loses once, so the blade is savage against
-- a robe and poor against a knight -- the same trade the wolves make, and the reason a brave weapon
-- is a read rather than simply more damage. Balance.MAGNITUDE_WAIVERS carries the ladder's half of
-- this argument, since a magnitude eight under its rung is exactly what that list exists to justify.
--
-- TWO LANDINGS, ONE WOUND. Daggers bleed (docs/weapons.md) and this one does, on the family contract
-- rather than as a flourish -- the wound rides whichever bite lands, carried inside the damage call
-- the way an on-hit status must be. Bleed refreshes rather than stacks (Status.apply keeps the longer
-- remaining), so striking twice opens one wound and not two; what the second strike buys is damage.
-- Everything ELSE that rides a landing does pay out twice, and that is the interesting half of the
-- purchase: two accuracy rolls, two chances at a critical, and a neighbouring Vampiric Strike charm
-- drinking from each bite separately.
--
-- CLASS `rogue`, NOT `hunter`, and the reason is the family cluster rather than the fiction. A class is
-- the shelf that stocks a thing, and docs/classes.md gives the hunter shelf bows and longbows only --
-- the knife is the rogue's (tests/class_spec.lua pins it both ways). So the wolf-taught trick comes off
-- a beast in the wood and belongs, as a piece of gear, to the people who fight with knives. Which reads
-- correctly anyway: nobody on the Lodge's shelf was ever going to swing this.
--
-- Unpriced: it comes off the White Wolf and nowhere else, and `dropTier` is set by the grading pass
-- (`. drop-tier`) rather than chosen here.
local Curve = require("models.curve")

return {
    name = "The Second Bite",
    description = "Strikes twice. Inflicts Bleed.",
    flavor = "The smith had never seen the animal. She had seen what it left, twice, in the same person.",
    sprite = "assets/items/the_second_bite.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    unlockLevel = 14,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    hands = 1,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, like every dagger
        cost = { stat = "stamina", amount = 5 },
        -- Under the Iron Dagger's opening 5-to-15, and see the header for the arithmetic: the brave
        -- rule repeats the wielder's attack stat as well as this number, so this number is the only
        -- place the doubling can be paid for and it pays the whole of it.
        damage = Curve.ramp(7, 17),
        -- THE BRAVE RULE (Item.strikes). Two landings, each its own hit roll, crit roll and armour
        -- subtraction. Deliberately not a magnitude: the forge buys a heavier blow, never a longer
        -- flurry.
        strikes = 2,
        effect = function(fx)
            local target = fx.target
            if not target then return end
            -- ONE fx.damage, and the rule turns it into two. The wound rides the blow: a status
            -- carried by damage never goes through fx.applyStatus.
            fx.damage(target, { inflicts = "status_bleed" })
        end,
    },
}
