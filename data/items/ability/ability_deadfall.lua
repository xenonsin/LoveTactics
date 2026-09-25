-- DEADFALL: the Kobold Trapwright's trap, and the drop off it. Round 2 (2026-09-25): the Tripline was
-- denied on both the body and the drop ("Change the trap itself"), and Deadfall was picked over Jar of
-- Vermin and Drop Net.
--
-- RIG A TILE, AND THE 3x3 AROUND IT IS THE TRAP (hazard_deadfall_rig). It is SEEN, not hidden -- the one
-- thing the trapper shelf's jaws, snares and stakes are not -- and it is hostile ground, so every planner
-- walks round it. A foe that steps into it springs it: the rocks come down a TURN LATER on the whole 3x3
-- (hazard_deadfall_falling, the landing shown for that turn), for impact, and leave the ground rough.
-- Delayed and wide where the rest of the shelf is instant and single: a trap you can see coming and step
-- out of, which is the "not a gotcha" read the Tripline was pitched on.
--
-- The rig is cast as SUPPORT for the planner's sake (Banner of the Mountain's precedent): a cast whose whole
-- payload is a board mutation scores only as a friendly one (AI.WEIGHTS.MUTATION). An unstocked trophy.
local Curve = require("models.curve")

return {
    name = "Deadfall",
    description = "Rigs a 3x3. The first foe to step in springs it: a turn later, rocks fall on the square and leave it rough.",
    flavor = "A prop, a rope and a great deal of rock that was already up there. The kobolds only arranged it.",
    sprite = "assets/items/ability_deadfall.png",
    type = "ability",
    tags = { "trap", "impact", "physical" },
    class = "trapper",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 4,
        support = true,
        cooldown = 20,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(8, 22), -- the rocks, carried onto the rig as its magnitude
        effect = function(fx)
            -- NEVER UNDER A BODY. A zone laid onto an occupied tile is an entry (Hazard.place), so a rig
            -- cell set under a foe would spring before its eight neighbours were even laid -- a half-rig,
            -- sprung by the act of rigging. Those cells are simply left out of the square.
            local rig = { cells = {} }
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local x, y = fx.tx + dx, fx.ty + dy
                    if not fx.unitAt(x, y) then
                        local h = fx.placeHazard(x, y, "hazard_deadfall_rig",
                            { side = fx.user.side, amount = fx.amount })
                        if h then
                            h.rig = rig
                            rig.cells[#rig.cells + 1] = h
                        end
                    end
                end
            end
        end,
    },
}
