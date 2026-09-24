-- TAKE WING: the wyvern going up, and -- because it is a WIND-UP -- the dive it always comes back down in.
--
-- ON THE BEAT IT LEAVES: every foe beside it is blown a tile back, and it is Aloft (status_aloft, this
-- ability's `channelStatus`) -- off every aim, immune to every blow, unmovable -- for exactly as long as
-- the wind-up lasts, about a turn.
--
-- WHEN IT RESOLVES it Stoops (models/stoop.lua): it comes down beside the foe it marked, and if that body
-- is standing ALONE -- nobody from its side directly beside it -- it carries the body up to three tiles
-- off, away from its company, and drops it. At or under twice the wyvern's Damage the fall kills; above
-- that it is the whole of the dive's harm. A body with a friend at its shoulder is landed beside and
-- nothing more, and the wyvern is then on the ground next to somebody with its Tailwind gone.
--
-- THE DIVE IS FORCED BY CONSTRUCTION, which is what the review asked for ("it has to dive after using
-- take wing"): Combat.resolveChannel runs this effect when the wyvern's slot comes round, with no choice
-- left in it. The mark is the tile; `target` is re-read there at resolution, so a body that walked off it
-- was dodged -- and the channel's tell painted that tile for exactly that reason.
--
-- It cannot be taken while Rooted: a wyvern held to the ground is the review's other counterplay.
local Curve = require("models.curve")
local Status = require("models.status")
local Stoop = require("models.stoop")

return {
    name = "Take Wing",
    description = "Blows back adjacent foes and goes aloft. Next turn, dives on the marked foe and carries it off if it stands alone.",
    flavor = "It is not fleeing. It is choosing again, from higher up.",
    sprite = "assets/items/ability_take_wing.png",
    type = "ability",
    class = "creature",
    tags = { "wind", "impact", "physical" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 5,
        speed = 4,
        windup = 5, -- a turn in the air
        cooldown = 15, -- three turns: it cannot live up there
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(8, 18), -- the drop
        channelStatus = "status_aloft",
        usable = function(unit)
            if Status.blocksForcedMove(unit) then return false, "Held to the ground" end
            return true
        end,
        effect = function(fx)
            if fx.clearStatus then fx.clearStatus(fx.user, "status_aloft") end
            Stoop.dive(fx, 3)
        end,
    },
}
