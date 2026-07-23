-- Heave: grab whatever is standing on an adjacent tile and throw it. A generic verb, not a demon's
-- trick: anyone can carry it, and it does not care what it picks up.
--
-- It aims an adjacent TILE (allowOccupied) rather than a target, and the effect reads what is on that
-- tile in one order:
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
-- rule a thrown body does (Combat.hurlObject mirrors Combat.knockback): a straight lane away from the
-- thrower, stopped by the edge, the terrain, an object or a body, and a stopped throw hurts both ends
-- worse the more of the trip it was denied.
--
-- Pure displacement -- no damage of its own on open ground; the wall, the fire, the fall and the keg do
-- the talking.
--
-- The Demon Champion is one USER of this, not its owner: its AI throws an adjacent Bomblet at your line
-- (data/characters/character_demon_champion.lua). It is a normal, grantable ability everywhere else.
return {
    name = "Heave",
    description = "Grabs an adjacent body, banner, barrel or trap and throws it three tiles. A collision hurts both sides.",
    flavor = "The strong have always known the shortest way to move a problem is to pick it up.",
    sprite = "assets/items/ability_push.png", -- placeholder until its own art exists
    type = "ability",
    tags = { "impact", "physical" },
    class = "fighter",
    price = 220,
    repRank = 2,
    activeAbility = {
        target = "tile",       -- an adjacent tile, so what is thrown may be friend, foe or furniture
        allowOccupied = true,
        range = 1,
        minRange = 1,          -- must pick a neighbor holding something, never the thrower's own tile
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 }, -- the collision's bite (only a blocked throw lands it)
        effect = function(fx)
            -- A body first: it is the thing standing ON the tile, and a unit and an object can never
            -- share one, so the order is a preference in name only.
            local body = fx.unitAt(fx.tx, fx.ty)
            if body then
                -- Flung straight away from the thrower; Combat.knockback stops it at walls / edges /
                -- units and deals the impact to everyone in the collision, doubled when the throw is
                -- denied.
                fx.knockback(body, 3, { amount = fx.amount })
                return
            end
            -- Otherwise whatever furniture is there: a prop, or a trap this side has found.
            local obj, kind = fx.objectAt(fx.tx, fx.ty)
            if obj then fx.hurl(obj, kind, 3, { amount = fx.amount }) end
        end,
    },
}
