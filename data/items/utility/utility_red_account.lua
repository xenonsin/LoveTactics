-- Brann's bound relic (Barbarian). The account is his own body, and the relic is the bill.
--
-- IT SHARPENS A PURCHASE RATHER THAN STANDING BESIDE ONE. The payoff is Fury -- an ability already on
-- the Barbarian shelf (data/items/ability/ability_fury.lua) -- with a stored blow folded in whose size
-- is the health he has ALREADY spent getting here. So the relic is not a rival to the shelf's best
-- cast; it is the reason to buy it.
--
-- A CENSUS ON HIS OWN BODY (`side = "self"`, `hpBelow`), not a tally: it opens at 40% spent, and it
-- SHUTS again if he heals back over the line. That is the tension worth having -- Vampiric Strike and
-- The Red Thirst sit on the same shelf and both buy the health back, and buying it back lowers the
-- payoff. A barbarian carrying this decides how much of his own life he is willing to still owe.
--
-- `bound`, no `price`: no vendor stocks it and the Blacksmith is the only thing that touches it. It
-- still carries `class`/`discipline`, for growth and identity rather than for the rack -- the shape
-- armor_rally_coat already wears, and what satisfies the tagging invariant in tests/discipline_spec.lua.
return {
    name = "The Red Account",
    description = "Casts Fury, and stores a blow worth one attack for every 1% of your health already spent.",
    flavor = "He does not count what is left. He counts what is owed, and he collects it himself.",
    sprite = "assets/items/sig_red_account.png",
    type = "utility",
    tags = { "signature", "physical" },
    class = "fighter",
    discipline = "barbarian",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        description = "Casts Fury and stores +1 attack per 1% of health already spent.",
        unlock = {
            field = { of = "unit", side = "self", hpBelow = 0.6, count = 1 },
            text = "Spend 40% of your health",
        },
        effect = function(fx)
            -- Read the debt BEFORE Fury lands: Fury drops him to 1 HP itself, so measuring afterwards
            -- would price every cast identically at 99% and make the gate decorative.
            local h = fx.user.char and fx.user.char.stats and fx.user.char.stats.health
            local max = (h and h.max) or 0
            local spent = max > 0 and (1 - ((h.current or 0) / max)) or 0
            fx.applyStatus(fx.user, "status_fury")
            fx.applyStatus(fx.user, "status_empowered", { magnitude = math.floor(spent * 100) })
        end,
    },
    -- Fury banked against your own health: the account is the bargain
    bonus = { damage = 3, defense = -1 },
}
