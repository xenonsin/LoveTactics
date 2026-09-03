-- The Long Prayer: the priest half of the Theurge (mage x priest). A channelled working that lays
-- sanctified ground -- and the longer it was held, the further the ground reaches.
--
-- The discipline's mechanic stated plainly: a miracle is not cast, it is WAITED FOR, and patience is
-- the only currency it takes. The channel is four ticks and the radius scales with the wind-up actually
-- served (fx.windup), so a theurge who was interrupted at two gets a smaller circle rather than nothing
-- -- which is what keeps the ability worth casting on a board with a stun on it, and what makes the
-- Vigil Beads an upgrade rather than a prerequisite.
--
-- Sanctified ground rather than a blast, because the priest half of this fusion is a ZONE discipline and
-- the mage half is what makes zones big. Invocation is the same fusion pointed at harm; this is the same
-- fusion pointed at holding a place open.
return {
    name = "The Long Prayer",
    description = "Channeled: leaves Sacred Ground in area, wider for each tick held.",
    flavor = "The words are short. It is the pauses between them that do the work.",
    sprite = "assets/items/ability_the_long_prayer.png",
    type = "ability",
    tags = { "holy" },
    class = "priest",
    discipline = "theurge",
    price = 165,
    unlockQuests = 1,
    activeAbility = {
        target = "tile",
        range = 4,
        speed = 6,
        windup = 4, -- winds up before it fires (Combat reads `windup`)
        support = true,
        cost = { stat = "mana", amount = 16 },
        description = "Channeled: leaves Sacred Ground in area, wider for the wind-up held.",
        effect = function(fx)
            -- One tile of reach per two ticks held, floored at 1: an interrupted prayer still leaves a
            -- patch of holy ground rather than nothing, so the wind-up is a scale and not a gate.
            local r = 1 + math.floor((fx.windup or 0) / 2)
            for dy = -r, r do
                for dx = -r, r do
                    fx.placeHazard(fx.tx + dx, fx.ty + dy, "hazard_sacred",
                        { amount = 4 + fx.level, duration = 14 + fx.level })
                end
            end
        end,
    },
}
