    -- DEEP SLEEP: one of the Glacier King's own. Sloth's one gift -- rest -- once a battle, as the whole
-- action.
    --
    -- `unstocked`: the body's own piece, visible on its house's rack and never sold (docs/drops.md).
    return {
        name = "Deep Sleep",
        description = "Once per battle, fully restore your stamina and mana. It takes your action.",
        flavor = "You wake up somewhere else. You wake up ready.",
        sprite = "assets/items/utility_deep_sleep.png",
        type = "utility",
        class = "knight",
        unlockLevel = 10,
        unstocked = true,
        tags = { "utility" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        support = true,
        cooldown = 9999,
        effect = function(fx)
            fx.restore(fx.user, "stamina", 999)
            fx.restore(fx.user, "mana", 999)
        end,
    },
    }
