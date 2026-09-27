-- OPEN VEINS: the Hemomancer's first spell, and its drop (Wrath's vampires, round 2's "deal Bleed" rows). Every foe
-- in a 3x3 within 4 Bleeds -- a whole line made to pay for every step, and every wound a vampire's to drink from
-- (the Hemomancer opened it, so Running Feeds It hands the ticks to the Hemomancer).
return {
    name = "Open Veins",
    description = "Every foe in a 3x3 area Bleeds.",
    flavor = "A drawn-out syllable, and every scab in the square splits at once.",
    sprite = "assets/items/ability_open_veins.png",
    type = "ability",
    tags = { "blood", "magical" },
    class = "mage",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 4,
        cooldown = 10,
        cost = { stat = "mana", amount = 10 },
        aoe = { radius = 1, shape = "square" },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits() or {}) do
                if u.side ~= fx.user.side then fx.applyStatus(u, "status_bleed") end
            end
        end,
    },
}
