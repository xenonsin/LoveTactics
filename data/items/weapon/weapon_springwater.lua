-- Springwater: the Nymph's one kindness, and it is a kindness with legs -- a heal, and a turn of Haste
-- so the body she mended can get out of where it was being mended.
--
-- She is a spring before she is anything else, and a spring that only healed would make her the second
-- priest on a floor that already has a honey field. The Haste is what makes it hers: it is mobility
-- handed across, which is the Dryad line's whole claim, and one turn of it is about a step's worth.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Springwater",
    description = "Heals an ally and Hastes it for a turn.",
    flavor = "Cold, clear, and moving. It does not stay where it is put, and it would rather you didn't either.",
    sprite = "assets/items/springwater.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "water", "magical", "restorative" },
    noSteal = true,
    activeAbility = {
        target = "ally",
        range = 3,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 8 },
        ai = {
            { priority = "high", act = "support", targetPref = "most_wounded",
              when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.6 } },
        },
        effect = function(fx)
            fx.heal(fx.target, 6 + fx.level)
            fx.applyStatus(fx.target, "status_hasted", { duration = 6 })
        end,
    },
}
