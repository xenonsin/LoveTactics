-- Nell's bound relic (Exorcist). She sends things back.
--
-- BANISH IS ON THE SHELF, one body at a time; Dispel Illusions strips one lie; The Stayed Hand lifts
-- one rider. This is all of it at once and over an area -- every summoned thing within three tiles
-- goes, and every working laid on that ground goes with it. The shelf teaches the verb; the relic is
-- the sentence.
--
-- A TALLY RATHER THAN A CENSUS, deliberately, and it is one of the few here. A census would have to
-- count somebody else's summons -- which makes the gate a thing the ENEMY decides, so an exorcist
-- facing a fight with nothing conjured in it could never open her own signature. Casting three times
-- is hers.
--
-- fx.dismiss is the same seam Banish uses, so a dismissed summon leaves exactly as it always does
-- (its claims released, its summoner's reservation returned), and fx.dispel clears the footprint.
return {
    name = "The Rite Unspoken",
    description = "Banishes every summon within 3 and strips the ground of what was laid on it.",
    flavor = "Everything here was invited. She is simply the one who says when it ends.",
    sprite = "assets/items/sig_rite_unspoken.png",
    type = "utility",
    tags = { "signature", "holy" },
    class = "priest",
    discipline = "exorcist",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 15 },
        aoe = { radius = 3, shape = "square" },
        description = "Dismisses every summon caught, and clears the ground it stood on.",
        unlock = { event = "cast", count = 3, text = "Cast 3 times" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                -- Hers included: a rite that spared her own conjurings would be a spell rather than a
                -- rite, and the Exorcist shelf has never made that exception anywhere else.
                fx.dismiss(u)
            end
            fx.dispel()
        end,
    },
}
