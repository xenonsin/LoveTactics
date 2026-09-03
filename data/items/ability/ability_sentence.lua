-- Sentence: the Inquisitor's execute (rogue x priest). A holy blow on a Marked body that strips every
-- blessing off it first -- and kills outright if the mark has already done its work.
--
-- The dispel is the half the shelf could not have until S5. Confessor's Needle shipped with its dispel
-- clause missing and a header saying so, because the engine's only dispel cleared an AREA's illusions --
-- there was no way to take the blessings off one body. fx.dispelUnit is that, and it is the whole of
-- what S5 shrank to: the veto half was cut after four rounds of the author turning down interrupts.
--
-- Strip THEN strike, in that order and deliberately: an Aegis or a barrier comes off before the blow
-- lands rather than eating it. That ordering is most of the item's power and all of its point -- a
-- judgment is not a bigger hammer, it is the removal of everything that was protecting them.
--
-- Marked only. Mark of Heresy is the shelf's own setup, but any Mark serves -- a hunter's quarry-sign,
-- a Poacher's trap. The Inquisition is not fussy about who did the pointing.
local Curve = require("models.curve")

return {
    name = "Sentence",
    description = "Strips every blessing from a Marked foe, then strikes it with holy fire. Lethal to the weakened.",
    flavor = "The reading of it takes longer than the carrying of it out.",
    sprite = "assets/items/ability_sentence.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "inquisitor",
    price = 410,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 5,
        cost = { stat = "mana", amount = 14 },
        damage = Curve.ramp(10, 22),
        description = "Dispels a Marked foe's blessings, then burns it; executes it under a third.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if not fx.hasStatus(t, "status_mark") then
                fx.log("action", "Sentence cannot be passed on the unaccused.")
                return
            end
            -- Stripped BEFORE the blow, so a ward does not eat the judgment it was raised against.
            local taken = fx.dispelUnit(t)
            local hp = t.char.stats.health
            local frac = (hp.max > 0) and (hp.current / hp.max) or 1
            if not t.char.boss and frac <= 0.34 then
                fx.damage(t, { amount = hp.max, raw = true })
            else
                fx.damage(t, { amount = fx.amount + #taken * 4 })
            end
        end,
    },
}
