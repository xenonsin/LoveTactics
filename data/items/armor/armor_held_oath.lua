-- Solene's bound relic (Paladin). She takes it instead.
--
-- VOW-MARKED PLATE IS THE OTHER HALF OF THE ENGINE: it hardens her for every debuff she carries, and
-- this pulls the party's onto her. The Oath's cost is the Plate's fuel, which is the cleanest
-- buy-both-or-neither on the roster. Lay On Hands does the same trade for one body; Oathkeeper's
-- Litany and Martyr's Icon hold the aura between uses.
--
-- THE GATE IS `allyStruck` -- a blow landing beside her, banked per neighbour per blow. That is the
-- right tally for a paladin because it counts the thing she is standing there to prevent, and it fills
-- on the ENEMY's turn, which is when she is doing the job.
--
-- fx.cleanse takes the debuffs off the ally; the same ids are applied to her rather than moved by a
-- primitive, because the engine has no transfer verb -- said out loud here rather than implied.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "The Held Oath",
    description = "Wards the whole party, and pulls what ails them onto yourself.",
    flavor = "She has never once asked whether they would do the same. It is not that kind of promise.",
    sprite = "assets/items/sig_held_oath.png",
    type = "armor",
    tags = { "signature", "holy", "shield" },
    class = "paladin",
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    waitBehavior = { kind = "defend", speed = 3, defense = Curve.ramp(5, 15) },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "mana", amount = 12 },
        description = "Aegis on your side, and their debuffs are taken onto you.",
        unlock = { event = "allyStruck", count = 4, text = "See 4 blows land beside you" },
        effect = function(fx)
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side == fx.user.side then
                    fx.applyStatus(u, "status_aegis")
                    if u ~= fx.user then
                        -- Copy what they carry onto her BEFORE clearing it, or the list is gone by the
                        -- time she takes it. Only what is actually a debuff: an Aegis lifted off an
                        -- ally and worn by the paladin would be a theft rather than a mercy.
                        for _, st in ipairs(u.statuses or {}) do
                            local def = st.def or Status.defs[st.id]
                            if def and def.debuff then fx.applyStatus(fx.user, st.id) end
                        end
                        fx.cleanse(u)
                    end
                end
            end
        end,
    },
}
