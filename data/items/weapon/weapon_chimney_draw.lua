-- THE CHIMNEY-DRAW: the Whirl Elemental's own sentence, and the only cast in the game where the answer depends
-- on what is already burning.
--
-- A FIRE CLIMBS BECAUSE IT DRAGS AIR IN BEHIND IT. That is the whole blueprint. The draw takes hold of
-- every foe in the circle it is aimed at and hauls -- and what it can hold ON to is fire. A body that is
-- already burning comes the WHOLE WAY, tile by tile, springing everything it crosses (Combat.pull); a
-- body that is not burning gets one stumbling step and keeps its formation. Then whatever is standing
-- against it when the haul stops catches fire, which arms the next draw.
--
-- SO THE ELITE IS A LOOP AND BOTH HALVES ARE VISIBLE FROM THE FIRST EXCHANGE. Walk up and swing, and
-- Backdraught lights your front rank (data/traits/trait_backdraught.lua). The lit rank is what the next
-- draw pulls all the way in. The Fire Elementals standing around it are not an escort, they are the fuel
-- line -- every one of them charges the party for the blows it throws, and every burn they hand out is
-- a handhold this body did not have to make for itself
-- (data/encounters/encounter_lust_the_flue.lua argues the pairing).
--
-- AND THE COUNTERPLAY IS FOUR THINGS A COMPANY ALREADY CARRIES, which is the standard the Lady Chapel
-- set for an elite on this ground. Cure the burn and the haul is a stumble. Kill the lamps first and
-- it has nothing to pull with -- the only fight on the stratum where clearing the chaff is the right
-- opening rather than the trap. Answer it at reach and never light yourself on it. Or take the haul
-- deliberately, on a body that wants to be adjacent to it, and let it spend its turn re-arranging
-- somebody who was coming anyway.
--
-- AIMED AT A TILE RATHER THAN CENTRED ON ITSELF, which is what stops it being a button. A circle thrown
-- two tiles out lets the body pick which knot of the company it gathers -- and fx.pull hauls toward the
-- CASTER regardless of where the circle was thrown, so the aim chooses the victims and the body chooses
-- the destination. Indrawn Breath's arrangement exactly (data/items/ability/ability_indrawn_breath.lua),
-- which is the player's version of this and is deliberately the thing it reads like.
--
-- THE DAMAGE IS INCIDENTAL AND SMALL. This circle does not kill you, it decides where you are standing
-- (models/descent.lua's Lust entry); the number here is what makes it a weapon rather than a hazard,
-- and everything that actually hurts arrives from the walls it drags people past and the fire it leaves
-- them in.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

-- One tile toward the caster. fx.knockback drives a body straight AWAY from its source unless handed a
-- destination, and `opts.dest` makes it walk toward that tile for as far as the tile is
-- (Combat.knockback) -- so the destination is one step along the dominant axis rather than the caster's
-- own tile, which would haul the body the whole distance and end in a collision. signDominant's rule,
-- restated because the primitive does not export it.
local function stumble(fx, victim)
    local dx, dy = fx.user.x - victim.x, fx.user.y - victim.y
    local sx, sy = 0, 0
    if math.abs(dx) >= math.abs(dy) then
        sx = (dx > 0 and 1) or (dx < 0 and -1) or 0
    else
        sy = (dy > 0 and 1) or (dy < 0 and -1) or 0
    end
    if sx == 0 and sy == 0 then return end
    fx.knockback(victim, 1, { dest = { x = victim.x + sx, y = victim.y + sy } })
end

return {
    name = "Chimney-Draw",
    description = "Hauls burning foes in a circle all the way in, and the rest a single tile. Whatever "
        .. "ends up adjacent catches fire.",
    flavor = "The room leans toward it. Every room it has ever been in has leaned toward it.",
    sprite = "assets/items/chimney_draw.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "fire", "impact", "physical", "ranged" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 3,
        requiresSight = true,
        speed = 6, -- the slowest thing it does: a haul is a commitment (the Beckoning Bough's rate)
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(4, 14),
        aoe = { radius = 2, shape = "square" },
        -- Worth the turn against a knot rather than a straggler. `count_at_least 2` is the floor and not
        -- the ideal -- the scorer already sums the effect over everyone it catches and prices friendly
        -- fire above enemy damage, so it finds the good draw without being told how.
        ai = { priority = "high", act = "attack",
               when = { subject = "any_foe", test = "count_at_least", value = 2 } },
        effect = function(fx)
            -- Haul first, light second, and in that order for the Indrawn Breath's reason: the drag is
            -- resolved one tile at a time and springs every trap and hazard on the way, so it is half
            -- the effect against a board the party has prepared. Lighting first would light them where
            -- they were rather than where the draw put them.
            for _, u in ipairs(fx.aoeUnits()) do
                if u ~= fx.user and u.side ~= fx.user.side and u.alive then
                    fx.damage(u)
                    if u.alive then
                        if fx.hasStatus(u, "status_burn") then
                            fx.pull(u) -- the fire is the handhold: it comes the whole way
                        else
                            stumble(fx, u) -- nothing to hold: one step, and it keeps its rank
                        end
                    end
                end
            end
            -- Re-read the footprint rather than reusing the list above: the haul has MOVED everyone,
            -- and the heap now standing against this body is not the circle it was gathered from.
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u ~= fx.user and u.side ~= fx.user.side and u.alive then
                    fx.applyStatus(u, "status_burn")
                end
            end
        end,
    },
}
