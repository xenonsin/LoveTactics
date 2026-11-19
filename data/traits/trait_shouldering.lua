-- SHOULDERING: the Orc Grunt's rule (data/items/utility/utility_shouldering.lua; 2026-11-19, the creature
-- identity pass).
--
-- A company body that ends its turn beside a Grunt is shoved one tile straight back (Combat.knockback, so a wall
-- or a body behind it is a collision and a hazard behind it is where it lands). It is the Blood Ring crowd's shove,
-- taken off the ring's edge and put on every Grunt on every board: the audit found the Grunt was "the race and
-- nothing else", and the one thing it already did that no other orc did was this, and only inside the Pit-Fighter's
-- fight.
--
-- So the Grunt is a POSITION lever: a body cannot settle in beside one, and a company that fights with its back
-- to fire or a ledge is fighting a line of Grunts that will put it there. No blow rides the shove -- that is the
-- Ring's, and a Grunt that struck on every turn end would be a stat lift, not a lever.
--
-- A Grunt standing as a SPECTATOR in the Blood Ring leaves the shove to the Ring (which shoves farther and
-- strikes), so the same body never shoves twice. A stunned Grunt does not shove: it is a reaction.
local DISTANCE = 1

return {
    name = "Shouldering",
    grade = 0.5, -- weighed beside the rule (Grade.traitValue reads it): a one-tile shove, no blow riding on it
    description = "A foe that ends its turn beside it is shoved 1 tile back.",
    distance = DISTANCE,
    onAnyTurnEnd = function(ctx)
        local u, combat, actor = ctx.unit, ctx.combat, ctx.actor
        if not (u and u.alive and combat and actor and actor.alive and actor.side ~= u.side) then return end
        local Status = require("models.status")
        if Status.has(u, "status_spectating") then return end
        local Combat = require("models.combat")
        if Combat.isOffTile(actor) or Combat.unitGap(u, actor) > 1 then return end
        local moved = Combat.knockback(combat, u, actor, ctx.param("distance", DISTANCE))
        if moved and moved > 0 then
            ctx.log("action", string.format("%s shoulders %s back.", (u.char and u.char.name) or "The orc",
                (actor.char and actor.char.name) or "it"), actor)
        end
    end,
}
