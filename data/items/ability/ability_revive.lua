-- Revive: the priest's miracle. It brings a fallen ally back to its feet where it lies -- the SAME
-- character, its kit and identity intact -- at half its health. Targets the ground: aim at the corpse
-- tile (a fallen unit stays on the field as a corpse; see Combat's corpse system). It succeeds only
-- while no living unit stands on top of that tile, and only for an ALLY's body -- you cannot revive a
-- foe. A support cast, so its cursor previews green.
return {
    name = "Revive",
    description = "Raise a fallen ally where they lie, restoring half their health.",
    sprite = "assets/items/ability_revive.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    price = 480,
    repRank = 4,
    activeAbility = {
        name = "Revive",
        target = "tile",
        support = true, -- friendly cast: preview green
        range = 3,
        power = { 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }, -- the percent of health restored (see the effect)
        speed = 6,
        cost = { stat = "mana", amount = 20 },
        effect = function(fx)
            local corpse = fx.corpseAt(fx.tx, fx.ty)
            -- Only an ally's body, and only if nobody stands on it (fx.corpseAt already refuses an
            -- occupied tile). fx.power is a percent; the reanimation takes it as a fraction of max HP.
            if corpse and corpse.side == fx.user.side then
                fx.reanimate(corpse, (fx.power or 50) / 100)
            end
        end,
    },
}
