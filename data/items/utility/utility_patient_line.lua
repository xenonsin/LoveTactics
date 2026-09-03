-- Sela's bound relic (Trapper). She wins the ground before anybody stands on it.
--
-- IT DOES NOT FIRE THE TRAPS, and that correction is the design. An earlier draft set every snare off
-- at once, which is nothing at all when nothing is standing on them -- and it made the right play
-- WAITING until the board filled, the opposite of what a trapper should be encouraged to do. This
-- widens instead: every trap she has laid takes the tiles around it, and so does every trap she lays
-- afterwards. Pressing it early is now correct, because everything after it is already wider.
--
-- THE FOREVER HALF LIVES IN THE ENGINE, not here: the cast banks `trapSpread` on her, and
-- models/trap.lua reads it on every placement (see the note beside Trap.place). That is what makes it
-- reach traps set six turns later, and it is why the flag is on the trapper rather than on the relic.
--
-- THE CENSUS IS FOUR ARMED TRAPS. Bear Trap, The Snare Stake, the Snare Stake Kit, The Blightstake and
-- the Caltrop Greaves are all both the gate and the payload -- every one bought is a wider field, and
-- buying them is also how the relic opens. The cleanest build-around on the roster.
local Trap = require("models.trap")

return {
    name = "The Patient Line",
    description = "Every trap you have laid, and every trap you lay after, spreads a tile in each direction.",
    flavor = "The line was never the traps. It was the ground she had already decided about.",
    sprite = "assets/items/sig_patient_line.png",
    type = "utility",
    tags = { "signature", "primal" },
    class = "hunter",
    discipline = "trapper",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        description = "Widens every trap you have set, and every trap you set afterwards.",
        unlock = {
            field = { of = "trap", count = 4,
                      test = function(t, unit) return t.placer == unit end },
            text = "4 of your traps armed",
        },
        effect = function(fx)
            -- The flag first, through fx.bank -- a mutation the damage preview must replay inertly
            -- rather than actually setting (see the note on fx.bank in models/combat.lua).
            fx.bank("trapSpread", true)
            -- Then widen what is already down. Snapshotted before placing, or the new copies would be
            -- walked by the same loop and spread again a tile at a time across the whole board.
            local laid = {}
            for _, t in ipairs((fx.combat and fx.combat.traps) or {}) do
                if t.alive and t.placer == fx.user then laid[#laid + 1] = t end
            end
            for _, t in ipairs(laid) do
                for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
                    Trap.place(fx.combat, t.x + step[1], t.y + step[2], t.id, t.side,
                        { amount = t.amount, placer = fx.user, spread = true })
                end
            end
        end,
    },
    -- the line was the ground she had already decided about
    bonus = { skill = 2 },
}
