-- THE KING'S LEVER: the Goblin King's drop (round 1, 2026-09-26, with the Rigged Hall). Mark a row of five; next
-- turn anyone still on it takes heavy damage and burns. The King's own lever downs outright (ability_rigged_hall);
-- the one a company carries out of his hall hurts instead, because a player's trap that downed whatever stood
-- on it would be a delete button with a turn's delay.
--
-- A trap you can see coming -- the trapper shelf's Deadfall read, laid in a line rather than a square.
local Curve = require("models.curve")

return {
    name = "The King's Lever",
    description = "Marks a row of five for a turn; then it opens into fire, dealing damage and Burn to everyone on it.",
    flavor = "It came off in his hand. It does still work.",
    sprite = "assets/items/ability_kings_lever.png",
    type = "ability",
    tags = { "trap", "fire", "magical" },
    class = "trapper",
    unlockLevel = 8,
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 5,
        minRange = 1,
        speed = 4,
        windup = 5,
        cooldown = 15,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(11, 26),
        aoe = { shape = "front", width = 5 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.alive then
                    fx.damage(u)
                    fx.applyStatus(u, "status_burn")
                end
            end
        end,
    },
}
