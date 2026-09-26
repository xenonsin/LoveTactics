-- THROUGH THE ROCK: the Barrow-Wight's drift as one cast. Step to an empty tile up to 3 away, through rock
-- and bodies alike. A go-under for the Deep-Delver's Pick (it stamps Surfaced on a bearer of that).
return {
    name = "Through the Rock",
    description = "Move to an empty tile up to 3 away, through walls and bodies.",
    flavor = "The wight never learned where the walls were. It never needed to, and after this, neither do you.",
    sprite = "assets/items/ability_through_the_rock.png",
    type = "ability",
    tags = { "dark" },
    class = "skirmisher",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 3,
        cooldown = 10,
        support = true,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            if fx.unitAt(fx.tx, fx.ty) then return end
            fx.teleportUser(fx.tx, fx.ty)
            if require("models.trait").flag(fx.user, "critOnSurfacing") then
                fx.applyStatus(fx.user, "status_surfaced")
            end
        end,
    },
}
