-- Confessor's Needle: the rogue half of the Inquisitor (rogue x priest). A dagger, so it bleeds like
-- every dagger (docs/weapons.md), and it carries `holy`, so demonic flesh dreads it. Its EXTRA is
-- judgment: against a foe already Marked (data/status/status_mark.lua -- painted by the Mark of Heresy),
-- the execution window doubles, and a failing heretic is put down outright. Mark, then judge.
--
-- NOTE: the approved design also "dispels the target's buffs"; that half waits on a confirmed
-- single-target dispel primitive (fx.dispel currently clears an AoE footprint), rather than a guess.
local Curve = require("models.curve")

return {
    name = "Confessor's Needle",
    description = "Inflicts Bleed and holy damage; executes a failing foe, and executes a Marked one from far higher.",
    flavor = "The charge is read. The Mark is the verdict. This is only the sentence.",
    sprite = "assets/items/weapon_confessors_needle.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "holy", "melee" },
    class = "rogue",
    discipline = "inquisitor", -- rogue x priest; the Judgment mechanic's first stock
    price = 610,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, like every dagger
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(13, 23), -- carries `holy` via the item tags
        effect = function(fx)
            local hp = fx.target.char and fx.target.char.stats and fx.target.char.stats.health
            -- Judgment: an ordinary failing foe is executed near death; a MARKED one from far higher,
            -- so the Mark of Heresy is what widens the sentence. Sized off max HP so it means the same
            -- against a boss as a rat (the standing execute idiom -- see weapon_kingsblood_dagger).
            -- Daggers bleed (docs/weapons.md), and the wound rides whichever blow lands, so a guardian
            -- who takes the hit takes the cut too. (An execute simply fells the target; no bleeding a corpse.)
            local bleed = "status_bleed"
            if hp and hp.max > 0 then
                local marked = fx.hasStatus(fx.target, "status_mark")
                local window = (marked and 0.30 or 0.12) + 0.01 * fx.level
                if (hp.current / hp.max) <= window then
                    fx.damage(fx.target, { amount = hp.max, raw = true, inflicts = bleed })
                else
                    fx.damage(fx.target, { inflicts = bleed })
                end
            else
                fx.damage(fx.target, { inflicts = bleed })
            end
        end,
    },
}
