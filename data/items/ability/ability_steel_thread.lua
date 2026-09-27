-- STEEL THREAD: the Oni Shadow's third verb, and its drop. Round 1 approved it with the note "steel thread needs a
-- rework, it can't move when rooted"; round 2 denied a wire (a movement toll: "this is bleed"), a strung line and a
-- plain root, and the author named the replacement: ROOT AND MARK (2026-09-27, "The Oni of Wrath").
--
-- So it is two existing statuses and nothing new: Root (the body cannot walk) and Mark (it is easier to hit and to
-- crit, and cannot vanish). On a board with oni, a Mark is a crit waiting to happen -- which is what snaps a horn,
-- so the thread is as useful against the clan as for it.
return {
    name = "Steel Thread",
    description = "Roots a foe within 4 and inflicts Mark.",
    flavor = "Thinner than hair and stronger than the arm on the other end of it.",
    sprite = "assets/items/ability_steel_thread.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "ninja",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 3,
        requiresSight = true,
        cooldown = 10,
        cost = { stat = "stamina", amount = 6 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local t = fx.target
            if not (t and t.alive) then return end
            fx.applyStatus(t, "status_root", { duration = 10 })
            fx.applyStatus(t, "status_mark")
        end,
    },
}
