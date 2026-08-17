-- Zosia's bound relic (Poisoner). She does not do the killing. She starts it, and this is the day it
-- all comes due at once.
--
-- THE COATINGS ARE BOTH THE GATE AND THE PAYLOAD. Envenom, Crawler Mucus, Thinblood Rime and Spiteful
-- Ichor are how five bodies come to be carrying poison at the same time, and The Miasma Flask is how
-- they carry it at the SAME time rather than one after another -- which is the distinction the census
-- draws and a tally could not. Five poisonings over five turns opens nothing.
--
-- THE VAT CASHES POISON IN AND ENDS IT. Worth stating beside Grell's Sealed Bell, which spreads
-- whatever is on the board and keeps it running: the two disciplines share a status and share nothing
-- else. Hers collects the debt, his makes more debtors.
return {
    name = "The Mother Vat",
    description = "Every poisoned body on the field pays its whole remaining debt at once.",
    flavor = "She has never been present for one of these. That is rather the point of them.",
    sprite = "assets/items/sig_mother_vat.png",
    type = "utility",
    tags = { "signature", "poison" },
    class = "alchemist",
    discipline = "poisoner",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 10 },
        description = "Detonates the poison on every poisoned foe on the field.",
        unlock = {
            field = { of = "unit", side = "foe", status = "status_poison", count = 5 },
            text = "5 foes carrying poison",
        },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side and fx.hasStatus(u, "status_poison") then
                    -- Collected, then cleared: the debt is paid, so the status goes with it. A vat
                    -- that took the payment and left the poison running would be charging twice.
                    fx.damage(u, { tags = { "poison" } })
                    fx.clearStatus(u, "status_poison")
                end
            end
        end,
    },
}
