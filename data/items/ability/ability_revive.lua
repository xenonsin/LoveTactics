-- Revive: the priest's miracle. It brings a fallen ally back to its feet where it lies -- the SAME
-- character, its kit and identity intact -- at half its health. Targets the ground: aim at the downed
-- body's tile (a felled ally lies INCAPACITATED on the field while its revive window is open; once the
-- window runs out the body goes cold -- a corpse past reviving -- see Combat's corpse system). It
-- succeeds only while no living unit stands on top of that tile, only inside the window, and only for an
-- ALLY's body -- you cannot revive a foe. A support cast, so its cursor previews green.
return {
    name = "Revive",
    description = "Raises a fallen ally where they lie, restoring half their health.",
    flavor = "The miracle, and the Cathedral's entire claim on your attention.",
    sprite = "assets/items/ability_revive.png",
    type = "ability",
    tags = { "holy", "restorative" },
    class = "priest",
    price = 480,
    repRank = 4,
    activeAbility = {
        target = "tile",
        support = true, -- friendly cast: preview green
        range = 3,
        reviveHealth = { 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, 100 }, -- the percent of health restored (see the effect)
        speed = 6,
        cost = { stat = "mana", amount = 20 },
        effect = function(fx)
            local body = fx.downedAt(fx.tx, fx.ty)
            -- Only an ally's INCAPACITATED body -- one still inside its window -- and only if nobody
            -- stands on it (fx.downedAt already refuses an occupied tile). A body gone cold (turned to a
            -- corpse) is past reviving and fx.downedAt no longer returns it. fx.amount is a percent; the
            -- reanimation takes it as a fraction of max HP.
            if body and body.side == fx.user.side then
                fx.reanimate(body, (fx.amount or 50) / 100)
            end
        end,
    },
}
