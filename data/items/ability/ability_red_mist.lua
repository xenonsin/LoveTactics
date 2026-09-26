-- RED MIST: the Goblin Hexer's cloud, and the drop off it. Reviewed 2026-09-26 ("The Goblins of Wrath"): the
-- body and the drop approved in round 1, and Seeing Red re-read in round 2 on Keno's note -- "lose control of
-- them and they use any action towards any target".
--
-- A 3x3 cloud for two turns (hazard_red_mist). Anyone inside is SEEING RED (status_seeing_red): it does not
-- choose its turn -- it uses a random action from its own kit on a random target in range, friend, foe or
-- itself (AI.preempt). Goblins inside too; they do not care. The answer is spacing: nobody in the mist wants a
-- friend beside them, and a heavy hitter in the mist is the real risk.

return {
    name = "Red Mist",
    description = "Lays a 3x3 cloud for two turns. Anyone inside is Seeing Red.",
    flavor = "It does not make anyone angry. It only takes away the part of them that was deciding.",
    sprite = "assets/items/ability_red_mist.png",
    type = "ability",
    tags = { "curse", "magical" },
    class = "shaman",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 5,
        cooldown = 15,
        cost = { stat = "mana", amount = 12 },
        aoe = { radius = 1, shape = "square" },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            for _, c in ipairs(fx.aoeCells() or {}) do
                fx.placeHazard(c.x, c.y, "hazard_red_mist", { side = false })
            end
        end,
    },
}
