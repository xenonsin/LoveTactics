-- A longbow, so it owes that family's contract (docs/weapons.md): the shot is DRAWN over a turn, it
-- reaches two tiles past any bow, it keeps the dead point-blank band, and it is two-handed. What it
-- adds over data/items/weapon/weapon_iron_longbow.lua is that it does not aim at a body at all.
--
-- The iron longbow spends a turn to put one heavy arrow exactly where the archer chose. This one
-- spends the same turn to put FIVE light ones somewhere inside a two-tile spread -- the archer picks
-- the clearing, and the sky picks the tiles. It is the same bargain data/items/ability/ability_meteor_storm.lua
-- makes with the mage's shelf, at a hunter's scale and out of a hunter's pool: you buy coverage and
-- you give up the promise.
--
-- Two consequences, both deliberate and both the point:
--   * IT IS A CROWD WEAPON, and only a crowd weapon. Five arrows scattered over thirteen tiles will
--     mostly find dirt when one body stands there; against a line packed into a lane, most of them
--     find someone. Where the iron longbow wants a single valuable target, this one wants a mass.
--   * IT HITS YOUR OWN. Falling arrows are not aimed, so `aoeUnits` -- which a Careful Sigil can
--     narrow -- is deliberately not what this reads: it damages whoever is standing on a struck tile,
--     ally or enemy. Loose it over a melee your own line is in and you will pay for it.
--
-- Each tile is struck at most once (the impact points are drawn distinct, as Meteor Storm's are), so
-- no unit is ever hit twice by one volley: this is coverage, not focus. The `aoe` field is declared
-- only to PAINT the spread the volley may fall in; the arrows pick their own cells below, and picks
-- that land off the map are harmlessly skipped by fx.unitAt.
return {
    name = "Hailfall Longbow",
    description = "Drawn over a turn, then drops five arrows on random tiles in a wide spread. Hits allies too.",
    flavor = "Aim is a courtesy the Lodge extends to single animals. A herd gets weather instead.",
    sprite = "assets/items/hailfall_longbow.png",
    type = "weapon",
    tags = { "longbow", "pierce", "physical", "ranged" },
    hands = 2, -- every bow is two-handed (docs/weapons.md)
    class = "hunter",
    price = 480,
    repRank = 4,
    activeAbility = {
        target = "tile",       -- ground, not a body: the volley falls on a place
        allowOccupied = true,  -- and that place may well have somebody standing in it
        range = 5,             -- a longbow's reach: two past a bow (docs/weapons.md)
        minRange = 2,          -- and a longbow's dead band
        requiresSight = true,
        speed = 4,
        channel = 2,           -- the draw. Hard control breaks it before a single arrow leaves
        cost = { stat = "stamina", amount = 10 },
        -- Per ARROW, and well under the iron longbow's single heavy shaft: five of these landing is a
        -- rout, one of them landing is a waste of a turn. That spread is the weapon.
        damage = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        aoe = { shape = "diamond", radius = 2 }, -- paints where the volley MAY fall (see the note above)
        effect = function(fx)
            -- The thirteen tiles of the radius-2 diamond around the aim point: the spread the archer
            -- chose, and every cell an arrow may come down on.
            local candidates = {}
            for dx = -2, 2 do
                for dy = -2, 2 do
                    if math.abs(dx) + math.abs(dy) <= 2 then
                        candidates[#candidates + 1] = { x = fx.tx + dx, y = fx.ty + dy }
                    end
                end
            end
            for _ = 1, math.min(5, #candidates) do
                local c = table.remove(candidates, fx.random(#candidates)) -- distinct impact tiles
                local u = fx.unitAt(c.x, c.y)
                -- Whoever is standing there. NOT fx.aoeUnits: an arrow that was never aimed cannot be
                -- steered around a friend, and a Careful Sigil has nothing to steer.
                if u then fx.damage(u) end
            end
        end,
    },
}
