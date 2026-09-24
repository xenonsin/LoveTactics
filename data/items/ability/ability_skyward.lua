-- SKYWARD: the Highwing's hand-over, and the wyvern's Take Wing worn by a person -- the landing half only.
-- Mark a foe within four; everyone beside you is blown a tile back, and you are Aloft (status_aloft): out
-- of every aim, immune to every blow, unable to act. When the wind-up resolves you MUST come down, beside
-- the mark if it is still standing there, and strike it as you land. If it walked off the tile you come
-- down on it harmlessly -- the same dodge the wyvern's tell offers.
--
-- An escape that commits you to a landing, which is why it is a wind-up and not a blink: the channel does
-- the forcing (Combat.resolveChannel), so there is no turn to spend deciding not to come down.
local Curve = require("models.curve")
local Status = require("models.status")
local Stoop = require("models.stoop")

return {
    name = "Skyward",
    description = "Blows back adjacent foes and goes aloft, out of reach. Next turn, lands beside the marked foe and strikes it.",
    flavor = "The Lodge teaches it as a way out. Everybody who has used it calls it a way in.",
    sprite = "assets/items/ability_skyward.png",
    type = "ability",
    tags = { "wind", "impact", "physical", "movement" },
    class = "skirmisher",
    unlockLevel = 5,
    unstocked = true,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 4,
        windup = 5,
        cooldown = 20,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(10, 20),
        channelStatus = "status_aloft",
        usable = function(unit)
            if Status.blocksForcedMove(unit) then return false, "Held to the ground" end
            return true
        end,
        effect = function(fx)
            if fx.clearStatus then fx.clearStatus(fx.user, "status_aloft") end
            if not (fx.combat and fx.combat.arena) then
                if fx.target then fx.damage(fx.target) end
                return
            end
            local body = Stoop.comeDown(fx)
            if body then fx.damage(body) end
        end,
    },
}
