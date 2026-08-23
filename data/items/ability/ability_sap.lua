-- Sap: a blow struck not to kill but to TAKE -- and what it takes is the arm itself.
--
-- IT USED TO DRAIN STAMINA, which made it a second Cutpurse Knife (data/items/weapon/
-- weapon_cutpurse_knife.lua) rather than an item: same class, same range, same rung, same price, and
-- the same two lines of drain-then-restore. The knife won every one of those comparisons -- quicker,
-- cheaper, bleeding on top, and costing no ability slot -- so this was a worse copy of a weapon the
-- shelf already sold, and the stamina theft is the knife's ladder rung to keep (docs/weapons.md).
--
-- What is left is the promise this file's own header used to make and never keep. Pickpocket lifts an
-- ITEM, Drain Mana siphons a RESOURCE, and this was supposed to be the third verb -- a STAT -- while
-- actually siphoning a second resource. It is the stat one now: the blow takes Damage off the victim
-- (status_sapped) and puts exactly that much on the thief (status_stolen_strength), matched magnitude,
-- opposite sign, same duration. The Lent Guard / Given Guard pair says the same sentence about armour;
-- this is greed's version, and greed does not lend.
--
-- WHAT IT ASKS THE PLAYER. A transfer can only move what is there, so the theft is capped at the
-- victim's own Damage -- rob the ogre, not the scribe. That is a different question from the one the
-- knife asks (which wants a foe with reflexes to bankrupt), and it points at a different body on the
-- same board: the knife opens up the duelist, this one robs the heavy hitter and swings with its arm.
-- Both halves land on the target the party least wants swinging, which is what makes one action worth
-- a turn: the damage the enemy loses is the damage the rogue gains, so the swing counts twice.
local Curve = require("models.curve")

return {
    name = "Sap",
    description = "Inflicts Sapped, moving the target's Damage to you as Stolen Strength.",
    flavor = "The Undercroft's second lesson in economy: strength is not a property of a man. It is a thing he is holding.",
    sprite = "assets/items/ability_sap.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    discipline = "thief", -- deeper cut of the shelf: buyable only once the thief gate is cleared
    price = 740,
    unlockQuests = 5,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(16, 26), -- the strike itself, attack-stat scaled like any blow
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- How much arm this swing is worth: a flat bite sharpened by the forge. Scaled off
            -- fx.level rather than a second authored magnitude because an ability names exactly one
            -- (models/item.lua), and this one's is its damage.
            local want = 4 + fx.level
            -- ...capped at what the victim's arm actually holds. Read off the character's BASE stat,
            -- not its effective one: the strength in the arm, never the sword in the hand, so the
            -- theft cannot compound with an earlier Sap's own cut or with the grid's bonuses. A body
            -- with no strength to speak of yields nothing, and the badge that lands on it says so.
            local base = (t.char and t.char.stats and t.char.stats.damage) or 0
            local take = math.min(want, base)
            -- The cut RIDES the blow (opts.inflicts) rather than following it, which buys two things:
            -- the arm is lighter before the on-hit reflexes answer, and the damage core skips the
            -- rider entirely on a killing blow -- no sapping a corpse.
            fx.damage(t, { inflicts = { id = "status_sapped", magnitude = -take } })
            -- ...and the same amount, positive, on whoever swung. Gated on the victim surviving so the
            -- ledger balances: a blow that killed took no arm, and the thief wears nothing for it.
            -- Deliberately NOT gated on `take > 0` as well -- the tooltip's dry run has no attack stat
            -- on its stand-in target (Combat.abilityOutput), so a guard on the amount would drop both
            -- badges out of the item's glossary and the card would describe an ability that does
            -- nothing. A 0-magnitude pair on a strengthless body is the honest reading anyway.
            if t.alive then
                fx.applyStatus(fx.user, "status_stolen_strength", { magnitude = take })
            end
        end,
    },
}
