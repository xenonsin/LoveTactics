-- THE SECOND BITE: the pack's teeth, forged.
--
-- The one weapon in the game that strikes twice for being quicker than what it is aimed at -- Fire
-- Emblem's doubling rule, which the wolves have been using on the party since weapon_wolf_fangs learned
-- it, handed back the other way round.
--
-- THE THRESHOLD IS RE-SCALED, NOT COPIED, and this is the number to argue with if anything here is
-- wrong. Fire Emblem doubles at four points of attack speed on a stat that runs to thirty; this game's
-- speed runs 0-9 with the entire cast packed into 3-6, so +4 would fire essentially never and the item
-- would be a lie on a card. At +2 it fires exactly where the cast is already split: the heavies --
-- knight, fighter, mage, paladin, bulwark -- all sit at 3, and the quick -- rogue, archer, duelist,
-- monk, thief -- all sit at 5. So a speed-5 body doubles the armoured half of every warband and none of
-- the quick half, which is a rule a player can hold in their head after one fight.
--
-- AND IT IS A BUILD, NOT A FREEBIE. The gap is read off Combat.flatStat, so gear and statuses both
-- count: a +speed charm, a Hasted turn, or the Wolfsong Horn's own speed line can buy a body over the
-- threshold it was sitting under, and a Sapped or Mired one can fall back under it. That is the whole
-- reason the figure is a gap rather than a flag -- it gives every point of speed in the game somewhere
-- to go.
--
-- WHAT IT COSTS. Two instances mean armour is subtracted twice (Combat.mitigatedDamage runs per hit),
-- so this is a savage thing to hold against a robe and a poor one to hold against plate -- which is the
-- same trade the wolves make, and the reason the doubling is not simply "more damage". The damage curve
-- is an iron dagger's exactly, because the second bite IS the upgrade and paying for it twice would be
-- the same purchase billed twice.
--
-- DAGGERS BLEED (docs/weapons.md) and this one does, on the family contract rather than as a flourish
-- -- the wound rides whichever bite lands. Bleed refreshes rather than stacks (Status.apply keeps the
-- longer remaining), so a doubled strike opens one wound, not two; what the second bite buys is damage,
-- and the wound is the family's.
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

local DOUBLE_GAP = 2 -- speed advantage needed to strike twice (see the header)

-- A body's effective speed, or nil when it cannot be read. Nil REFUSES the doubling rather than
-- defaulting it: the inventory tooltip dry-runs this effect against a stand-in target, and a forecast
-- that invented a second strike because a dummy read as speed 0 would be a promise the board never keeps.
local function speedOf(unit)
    if not (unit and unit.char and unit.char.stats) then return nil end
    local Combat = require("models.combat") -- inside the call: a data file must not close a load cycle
    local v = Combat.flatStat(unit, "speed")
    return (type(v) == "number") and v or nil
end

return {
    name = "The Second Bite",
    description = "Strikes twice when your Speed exceeds the target's by 2 or more. Inflicts Bleed.",
    flavor = "The smith had never seen the animal. She had seen what it left, twice, in the same person.",
    sprite = "assets/items/the_second_bite.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "melee" },
    class = "rogue",
    unlockLevel = 15,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    hands = 1,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, like every dagger
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(15, 25), -- an iron dagger's exactly: the second strike is what you are buying
        effect = function(fx)
            local target = fx.target
            if not target then return end
            -- The wound rides the blow: a status carried by damage never goes through fx.applyStatus.
            fx.damage(target, { inflicts = "status_bleed" })

            local mine, theirs = speedOf(fx.user), speedOf(target)
            if target.alive and mine and theirs and (mine - theirs) >= DOUBLE_GAP then
                fx.damage(target, { inflicts = "status_bleed" })
            end
        end,
    },
}
