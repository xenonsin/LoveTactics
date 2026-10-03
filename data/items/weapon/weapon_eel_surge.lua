-- EEL SURGE: the Sand-Eels' own (data/characters/character_sand_eel.lua; "Envy's Bestiary", round 3). Leviathan's
-- brood, at the size of a dog: it goes Underground and comes up where the Fairest stood, biting whoever is still
-- standing there.
--
-- DELVE'S SHAPE (data/items/ability/ability_delve.lua), on a body that does nothing else. On commit it goes
-- Underground (`channelStatus`) and the channel's ghost marks the tile it will come up on -- a turn's telegraph.
-- When the channel resolves it surfaces beside that tile and bites the body on it; if the Fairest moved, it bites
-- nothing. Between the bite and its next dive it is up, and that is the round to hit it in. Its planner aims at the
-- Fairest (models/envy_oneoffs.lua); anything else is the ordinary planner's choice.
local Curve = require("models.curve")
local Status = require("models.status")

return {
    name = "Eel Surge",
    description = "Goes Underground and surfaces a turn later beside the tile it aimed at, biting the body on it.",
    flavor = "The sand ripples once, the way water does over something that has noticed you.",
    sprite = "assets/items/weapon_eel_surge.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "bite", "pierce", "physical" },
    noSteal = true, -- a creature's body is not loot
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 6,
        speed = 4,
        windup = 5, -- a turn under the sand
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(6, 16),
        channelStatus = "status_underground",
        usable = function(unit)
            if Status.blocksMove(unit) then return false, "Cannot move" end
            return true
        end,
        effect = function(fx)
            if fx.clearStatus then fx.clearStatus(fx.user, "status_underground") end
            local victim = fx.unitAt(fx.tx, fx.ty)
            local x, y = fx.tx, fx.ty
            if victim and victim ~= fx.user then x, y = fx.openTileNear(fx.tx, fx.ty) end
            if x and y then fx.teleportUser(x, y) end
            if victim and victim ~= fx.user and victim.alive and victim.side ~= fx.user.side then
                fx.damage(victim)
            end
        end,
    },
}
