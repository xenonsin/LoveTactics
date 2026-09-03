-- Vess's bound relic (Assassin). She arrives once, at the end.
--
-- THE RESOURCE IS A MOVEMENT STYLE, which is what makes this a build rather than a cooldown. It banks
-- `tilesBlinked` -- ground crossed WITHOUT walking (models/combat.lua's Combat.teleportUnit) -- so
-- every blink in her grid is a purchase of damage. Shadow Strike closes, Stillshade breaks away, a
-- Blink stance repositions: none of those were bought for this, and all of them feed it.
--
-- Walking banks nothing here. That is the point and it is enforced at the seam rather than by this
-- file: Combat.moveUnit fills `tilesMoved` and teleportUnit fills `tilesBlinked`, and the two never
-- both fire. An assassin who solves a fight on foot has not charged her signature at all.
--
-- The blow is the distance, and she is back where she started before it lands -- so the tile she
-- spends the turn on is the tile she chose, not the one the kill happened on. Everything about the
-- errand is that she was never really there.
return {
    name = "The Quiet Errand",
    description = "Strikes anywhere in sight for the distance you have blinked, and returns you to your tile.",
    flavor = "The distance is the weapon. The knife is only how it arrives.",
    sprite = "assets/items/sig_quiet_errand.png",
    type = "utility",
    tags = { "signature", "pierce", "physical" },
    class = "assassin",
    activeAbility = {
        target = "enemy",
        range = 8,
        requiresSight = true,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        description = "Strikes for the distance you have blinked this fight.",
        unlock = { event = "tilesBlinked", count = 8, text = "Cross 8 tiles without walking" },
        -- The banked distance IS the damage, so the slot wears it: the badge and the blow read the
        -- same tally and can never disagree about what the next cast is worth.
        counter = function(unit)
            return unit and require("models.combat").tallyCount(unit, "tilesBlinked") or 0
        end,
        counterLabel = "Tiles",
        effect = function(fx)
            -- The banked distance IS the damage. Read live off the tally rather than stored, so a
            -- surplus collected past the gate is spent too -- eight tiles opens it, twelve hurts more.
            local Combat = require("models.combat")
            local banked = Combat.tallyCount(fx.user, "tilesBlinked")
            fx.damage(fx.target, { amount = banked })
        end,
    },
    -- striking anywhere in sight, for the ground you gave up
    bonus = { skill = 2 },
}
