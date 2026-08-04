-- Heave: grab whatever is standing on an adjacent tile and throw it WHERE YOU CHOOSE. A generic verb,
-- not a demon's trick: anyone can carry it, and it does not care what it picks up.
--
-- It is a TWO-STAGE throw (activeAbility.throw), so it aims twice. First you grab -- an adjacent TILE
-- (allowOccupied) holding a body, a prop, or a trap this side has found. THEN you pick a landing: any
-- tile up to three out along one of the four cardinal lines from the grabbed tile (the throw travels a
-- straight lane, and the engine's shoves are 4-directional). The thrown thing flies that lane and
-- either comes to rest where you pointed, or SLAMS into the first wall, unit or keg in the way -- so
-- aiming AT a body is how you drive the throw into it, and aiming at open ground is how you reposition
-- without a collision. Where the old Heave always flung its load straight away from the thrower, you
-- now say where it goes.
--
-- (An AI or a legacy caller that supplies no landing falls back to the old behavior: straight away from
-- the thrower, three tiles. That is what the Demon Champion's Bomblet lob still does.)
--
-- The effect reads what is on the grabbed tile in one order:
--   1. a BODY -- ally OR foe, and that includes the STANDING ones. Throw a foe off a vantage point,
--      into a fire, over a spike trap, or hard against a wall; throw a friend, shoving your archer
--      forward onto the high ground; or pick up a planted BANNER (data/characters/character_banner.lua)
--      and put the rally where the line actually broke. A banner is a real body that simply never
--      moves itself, so it needed nothing here -- and the ground it holds open travels with it
--      (Hazard.carry), so what arrives three tiles away is the whole 3x3 blessing and not an empty pole.
--      Heaving the ENEMY's banner is the same click, and is the cheapest way to drag a rally off the
--      allies it was lifting.
--   2. a PROP -- a powder keg, a supply crate (models/prop.lua). Kegs are the reason to look: a barrel
--      has one HP, so ANY collision destroys it and its onDestroy is the blast. Heave one into a line
--      of demons and it goes off in their teeth; heave it into open ground and it lands intact, which
--      is how you move a bomb somewhere useful without setting it off.
--   3. a TRAP you can SEE (your own, or an enemy's you have detected). Pick up the spike trap the
--      demons planted and put it three tiles further down their own approach -- or shift your own
--      caltrops onto the lane the fight actually went to. A trap that slams into something breaks on
--      impact, so a throw is not free.
--
-- Everything else about it is unchanged by that widening, because a thrown object travels by the same
-- rule a thrown body does (Combat.hurlObject mirrors Combat.knockback): a straight lane -- now aimed at
-- your chosen landing rather than fixed away from the thrower -- stopped by the edge, the terrain, an
-- object or a body, and a stopped throw hurts both ends worse the more of the trip it was denied.
--
-- Pure displacement -- no damage of its own on open ground; the wall, the fire, the fall and the keg do
-- the talking.
--
-- The Demon Champion is one USER of this, not its owner: its AI throws an adjacent Bomblet at your line
-- (data/characters/character_demon_champion.lua). It is a normal, grantable ability everywhere else.
local Curve = require("models.curve")

return {
    name = "Heave",
    description = "Grabs an adjacent body, banner, barrel or trap, then throws it to a tile up to three away. A collision hurts both sides.",
    flavor = "The strong have always known the shortest way to move a problem is to pick it up -- and where to set it down.",
    sprite = "assets/items/ability_push.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    price = 220,
    unlockQuests = 2,
    activeAbility = {
        target = "tile",       -- an adjacent tile, so what is thrown may be friend, foe or furniture
        allowOccupied = true,
        throw = true,          -- two-stage: grab the adjacent tile, THEN pick where it lands (Item.isThrow)
        throwRange = 3,        -- how far the landing may be from the grabbed tile (the battle UI's ray)
        range = 1,             -- the GRAB reach: an adjacent tile
        minRange = 1,          -- must pick a neighbor holding something, never the thrower's own tile
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = Curve.ramp(6, 16), -- the collision's bite (only a blocked throw lands it)
        effect = function(fx)
            -- A body first: it is the thing standing ON the tile, and a unit and an object can never
            -- share one, so the order is a preference in name only.
            local reach = fx.item.activeAbility.throwRange or 3 -- the fallback distance when no dest is aimed
            local body = fx.unitAt(fx.tx, fx.ty)
            if body then
                -- Flung toward the chosen landing (fx.dest); Combat.knockback walks that lane, stops it
                -- at walls / edges / units and deals the impact to everyone in the collision, doubled
                -- when the throw is denied. With no dest (AI / legacy) it falls back to straight away
                -- from the thrower, `throwRange` tiles.
                fx.knockback(body, reach, { amount = fx.amount, dest = fx.dest })
                return
            end
            -- Otherwise whatever furniture is there: a prop, or a trap this side has found.
            local obj, kind = fx.objectAt(fx.tx, fx.ty)
            if obj then fx.hurl(obj, kind, reach, { amount = fx.amount, dest = fx.dest }) end
        end,
    },
}
