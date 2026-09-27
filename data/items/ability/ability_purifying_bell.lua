-- PURIFYING BELL: the Oni Priestess's rite, and her drop. Approved 2026-09-26 ("The Oni of Wrath"), after
-- Reincarnated as a Slime's shrine maiden, whose work is to purify.
--
-- Every ally within 2 of the ringer, the ringer included, is cleansed of every debuff (fx.cleanse, the same door
-- Cure uses). A snapped horn is not a debuff, so the bell rings over it and leaves it snapped.
return {
    name = "Purifying Bell",
    description = "Cleanses every ally within 2 of all debuffs, you included.",
    flavor = "One note, and everything that was not meant to be on you remembers it has somewhere else to be.",
    sprite = "assets/items/ability_purifying_bell.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    unlockLevel = 7,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        cooldown = 10,
        cost = { stat = "mana", amount = 10 },
        aoe = { shape = "square", radius = 2 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local user = fx.user
            for _, u in ipairs(fx.aoeUnits()) do
                if u.alive and u.side == user.side then fx.cleanse(u) end
            end
        end,
    },
}
