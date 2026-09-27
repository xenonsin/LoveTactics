-- THE THIRST: what the vampire tag puts in the grid (data/items/utility/utility_the_thirst.lua, seeded by
-- Character.VAMPIRE_GRANT). The rules themselves live in models/thirst.lua; this is where they hang:
--
--   onTurnEnd        a dry turn climbs the Thirst, and at the threshold the vampire is in Bloodlust
--   scent "toward"   SCENT OF BLOOD: +2 movement on a move that closes on a bleeding foe (Combat.reachable)
--   damageBonusVs    ...and +20% of its own Damage against a bleeding foe
--
-- NOT A REFLEX (`notAReaction`): a stunned vampire is still thirsty.
return {
    name = "The Thirst",
    description = "Gain Thirst each turn you draw no blood; at 3, Bloodlust. Deal 20% more to and move 2 further toward bleeding foes.",
    scent = "toward",
    notAReaction = true,
    onTurnEnd = function(ctx)
        require("models.thirst").onTurnEnd(ctx.combat, ctx.unit)
    end,
    damageBonusVs = function(ctx)
        return require("models.thirst").scentDamage(ctx)
    end,
}
