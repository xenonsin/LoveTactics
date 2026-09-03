-- Grell's bound relic (Plague Knight). Standing near him is the attack.
--
-- IT SPREADS ANYTHING, NOT POISON, and that is the split with the Poisoner. Zosia's Mother Vat CASHES
-- poison in and ends it; this takes whatever is already on a body -- poison included, burn, sunder,
-- root, the lot -- and gives it to the neighbours. Two disciplines that share a status and share
-- nothing else: hers collects the debt, his makes more debtors.
--
-- COUNTING EVERY DEBUFF is what makes it his rather than hers. A census of poison alone would have been
-- her gate on his body. Six afflictions across the field is a board that has been WORKED, whoever did
-- the working -- so an ally's Sunder and a mage's Burn both feed the bell, which is the honest reading
-- of contagion.
--
-- Rot-Fume Gauntlet scales his damage with how many are poisoned, so the bell is what makes that number
-- large; Miasmal Plate and Pestilent Flail seed it; Contagion is the passive version of this same rule.
local Status = require("models.status")

-- Every debuff on a body, as ids. Read the same way in the census and in the payoff, so the gate and
-- the spread can never disagree about what counts.
local function afflictions(u)
    local ids = {}
    for _, st in ipairs(u.statuses or {}) do
        local def = st.def or Status.defs[st.id]
        if def and def.debuff then ids[#ids + 1] = st.id end
    end
    return ids
end

return {
    name = "The Sealed Bell",
    description = "Every affliction on a foe is copied onto every other foe within 2 of it.",
    flavor = "It has not been rung in a long time. Nothing about that was an accident.",
    sprite = "assets/items/sig_sealed_bell.png",
    type = "utility",
    tags = { "signature", "poison" },
    class = "plague_knight",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 6,
        cost = { stat = "stamina", amount = 11 },
        description = "Copies every affliction outward to its neighbours.",
        unlock = {
            field = { of = "unit", side = "foe", count = 6,
                      test = function(u) return #afflictions(u) > 0 end },
            text = "6 afflicted foes",
        },
        effect = function(fx)
            -- Read the whole board's afflictions BEFORE giving any of them away, or the spread would
            -- chase itself outward across the field from the first body it touched.
            local carried = {}
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.side ~= fx.user.side then
                    carried[#carried + 1] = { unit = u, ids = afflictions(u) }
                end
            end
            for _, source in ipairs(carried) do
                for _, near in ipairs(fx.unitsNear(source.unit.x, source.unit.y, 2) or {}) do
                    if near ~= source.unit and near.side ~= fx.user.side then
                        for _, id in ipairs(source.ids) do fx.applyStatus(near, id) end
                    end
                end
            end
        end,
    },
    -- one affliction spread across a field
    bonus = { magicDamage = 2 },
}
