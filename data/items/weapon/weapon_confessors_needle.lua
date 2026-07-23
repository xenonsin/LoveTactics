-- Confessor's Needle: the rogue half of the Inquisitor (rogue x priest). A dagger, so it bleeds like
-- every dagger (docs/weapons.md), and it carries `holy`, so demonic flesh dreads it. Its EXTRA is
-- judgment: against a foe already Marked (data/status/status_mark.lua -- painted by the Mark of Heresy),
-- the execution window doubles, and a failing heretic is put down outright. Mark, then judge.
--
-- NOTE: the approved design also "dispels the target's buffs"; that half waits on a confirmed
-- single-target dispel primitive (fx.dispel currently clears an AoE footprint), rather than a guess.
return {
    name = "Confessor's Needle",
    description = "Inflicts Bleed and holy damage; executes a failing foe, and executes a Marked one from far higher.",
    flavor = "The charge is read. The Mark is the verdict. This is only the sentence.",
    sprite = "assets/items/weapon_confessors_needle.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "holy", "melee" },
    class = "rogue",
    discipline = "inquisitor", -- rogue x priest; the Judgment mechanic's first stock
    price = 260,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, like every dagger
        cost = { stat = "stamina", amount = 5 },
        damage = { 6, 7, 8, 8, 9, 10, 11, 11, 12, 13, 14 }, -- carries `holy` via the item tags
        effect = function(fx)
            local hp = fx.target.char and fx.target.char.stats and fx.target.char.stats.health
            -- Judgment: an ordinary failing foe is executed near death; a MARKED one from far higher,
            -- so the Mark of Heresy is what widens the sentence. Sized off max HP so it means the same
            -- against a boss as a rat (the standing execute idiom -- see weapon_kingsblood_dagger).
            if hp and hp.max > 0 then
                local marked = fx.hasStatus(fx.target, "status_mark")
                local window = (marked and 0.30 or 0.12) + 0.01 * fx.level
                if (hp.current / hp.max) <= window then
                    fx.damage(fx.target, { amount = hp.max, raw = true })
                else
                    fx.damage(fx.target)
                end
            else
                fx.damage(fx.target)
            end
            fx.applyStatus(fx.target, "status_bleed") -- daggers bleed (docs/weapons.md)
        end,
    },
}
