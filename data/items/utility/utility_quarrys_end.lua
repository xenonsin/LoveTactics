-- Rask's bound relic (Poacher). He sets the trap, then collects -- and this is the setting, not the
-- collecting.
--
-- IT IS NOT AN EXECUTE, and the correction is the design. An earlier draft killed every Rooted foe on
-- the field, which is Throatcut with a bigger footprint -- it replaced the shelf's payoff instead of
-- arming it. This does the other half: everything on the board is Rooted and Marked at once, and then
-- the whole Poacher shelf goes live in a single turn. Throatcut and Poacher's Kris both pay bonuses
-- against exactly this state, and The Long Wait means attacks on it cannot be answered.
--
-- SO THE RELIC MAKES A ROUND rather than a kill: he presses it, and every blow anybody on his side
-- throws for the next turn is a poacher's blow. Bolas, Spike Trap and Quarry's Due are the one-body
-- versions that teach the verb and fill the gate.
return {
    name = "Quarry's End",
    description = "Roots and Marks every foe on the field at once.",
    flavor = "The hunt was over some time ago. This is the part where he says so.",
    sprite = "assets/items/sig_quarrys_end.png",
    type = "utility",
    tags = { "signature", "primal" },
    class = "rogue",
    discipline = "poacher",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 11 },
        description = "Every foe is Rooted and Marked, opening them to the whole shelf.",
        unlock = { event = "hitDealt", count = 3, text = "Land 3 blows" },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_root")
                    -- Mark carries `preventsInvisible` in the status itself, so nothing marked here can
                    -- slip back out of sight before the shelf collects on it.
                    fx.applyStatus(u, "status_mark")
                end
            end
        end,
    },
}
