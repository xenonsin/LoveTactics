    -- THE SLOW HOUR: one of the Glacier King's own (data/characters/character_glacier_king.lua). His Torpor,
-- aimed: one deep shove of an adjacent foe's turn.
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "The Slow Hour",
        description = "Make an adjacent foe Torpid, pushing its next turn back a full turn.",
        flavor = "It will get there. Eventually.",
        sprite = "assets/items/utility_the_slow_hour.png",
        type = "utility",
        class = "knight",
        unlockLevel = 10,
        unstocked = true,
        tags = { "control" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        cooldown = 30,
        effect = function(fx)
            fx.applyStatus(fx.target, "status_torpid", { magnitude = 5, applier = fx.user })
        end,
    },
    }
