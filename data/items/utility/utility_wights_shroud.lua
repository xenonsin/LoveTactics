local Curve = require("models.curve")

-- THE WIGHT'S SHROUD: the Barrow-Wight's. Half Here was pitched as a quarter-miss for a person and the
-- review said "just raise evasion" -- so it is Avoid, plainly, on the forge's track.
return {
    name = "Wight's Shroud",
    description = "Increase Avoid.",
    flavor = "It was a burial cloth. It has not decided which side of the grave it is on, and neither will you.",
    sprite = "assets/items/utility_wights_shroud.png",
    type = "utility",
    tags = { "cloak", "dark" },
    class = "skirmisher",
    unlockLevel = 5,
    unstocked = true,
    bonus = { avoid = Curve.ramp(10, 20) },
}
