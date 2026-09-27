-- BLACK-FLAME DOME: the Oni General's, and its drop. Approved 2026-09-26 ("The Oni of Wrath"), after Reincarnated
-- as a Slime's general whose black flame closes into a dome.
--
-- It marks a 3x3 for a turn (a wind-up, drawn like the Rigged Hall's row), and then the dome closes: everyone still
-- inside is Rooted for two turns and set Burning, and the nine tiles burn with them. The answer is the telegraph --
-- step out before it closes. Both sides are caught; a dome does not ask whose it is.
return {
    name = "Black-Flame Dome",
    description = "Marks a 3x3 area. Next turn it closes: everyone inside is Rooted for 2 turns and Burned, and the area burns.",
    flavor = "It is not hot, at first. That is what keeps people standing in it.",
    sprite = "assets/items/ability_black_flame_dome.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "warlord",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        speed = 4,
        windup = 5,
        cooldown = 20,
        cost = { stat = "mana", amount = 12 },
        aoe = { shape = "square", radius = 1 },
        ai = { priority = "urgent", act = "cast" },
        effect = function(fx)
            local user = fx.user
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= user and u.alive then
                    fx.applyStatus(u, "status_root", { duration = 10 })
                    fx.applyStatus(u, "status_burn")
                end
            end
            for _, c in ipairs(fx.aoeCells() or {}) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { side = false, duration = 10 })
            end
        end,
    },
}
