-- Lay On Hands: the priest half of the Paladin (knight x priest). Mends an ally, wards them, and takes
-- every affliction they were carrying onto yourself.
--
-- The transfer is the item. A cleanse removes a problem from the world; this MOVES it, and the paladin
-- is where it moves to. That is the discipline's whole claim about what a holy knight is for -- not the
-- one who fixes things, the one who agrees to carry them -- and it is the only heal in the game whose
-- cost is paid in something other than a resource bar.
--
-- It is also why the Vow-Marked Plate exists. Read alone, this ability is charity with extra steps:
-- you have taken a poison off a squishy body and put it on a slightly less squishy one. Read beside the
-- plate, every affliction you accept is a permanent lift to your own guard, and the paladin's answer to
-- a party covered in debuffs is to walk around collecting them.
--
-- Aegis on top of the mend, so the ally is not merely patched but braced -- the ward is the half that
-- makes this worth a turn when nobody is actually poisoned.
local Curve = require("models.curve")

return {
    name = "Lay On Hands",
    description = "Heals and wards an ally, and takes every debuff they carry onto yourself.",
    flavor = "Give it here. I have somewhere to put it.",
    sprite = "assets/items/ability_lay_on_hands.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "paladin",
    price = 400,
    unlockQuests = 9,
    activeAbility = {
        target = "ally",
        range = 1,
        speed = 4,
        support = true,
        cost = { stat = "mana", amount = 12 },
        healing = Curve.ramp(14, 29), -- Combat.abilityMagnitude reads this
        description = "Heals and wards an ally, then takes their afflictions onto yourself.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            fx.heal(t, fx.amount)
            fx.applyStatus(t, "status_aegis")

            -- Collected before any of it is moved: removing from a live list while walking it is how
            -- you leave half an affliction behind.
            local Status = require("models.status")
            local taken = {}
            for _, st in ipairs(t.statuses or {}) do
                local def = Status.defs[st.id]
                if def and def.debuff then taken[#taken + 1] = st.id end
            end
            for _, id in ipairs(taken) do
                Status.remove(fx.combat, t, id)
                fx.applyStatus(fx.user, id)
            end
            if #taken > 0 then
                fx.log("status", string.format("%d affliction%s change hands.",
                    #taken, #taken == 1 and "" or "s"))
            end
        end,
    },
}
