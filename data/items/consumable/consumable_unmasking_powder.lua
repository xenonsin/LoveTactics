-- UNMASKING POWDER: the answer to the Many Faced One's whole line, lifted off it (Descent.DROPS, behind its
-- relic). A 3x3 of fine grey dust: every foe in it is stripped of any shape it wears (fx.revert -- the transform
-- undone, the body underneath back on the board) and Halted for a turn, so the face it had does nothing first.
--
-- A Faceless reshapes at the top of its turn and the Many Faced One puts its form back on at the top of its own,
-- so the powder buys exactly the turn the Halt names: a window, never a cure. On a druid's bear or a pigged knight
-- it is the same verb. Unpriced and `unstocked`: the body is the only road to it.
return {
    name = "Unmasking Powder",
    description = "Throw: every foe in a 3×3 is stripped of any shape it wears and Halted for a turn.",
    flavor = "It does not show you what is underneath. It shows the thing underneath that you saw.",
    sprite = "assets/items/consumable_unmasking_powder.png",
    type = "consumable",
    tags = {},
    class = "bombardier",
    unlockLevel = 12,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 5 },
        consumesItem = true,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    fx.revert(u)
                    fx.applyStatus(u, "status_halted")
                end
            end
        end,
    },
}
