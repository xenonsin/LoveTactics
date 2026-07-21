-- Meteor Storm: the mage marks a wide zone and calls down six meteors on random tiles within it.
-- Each meteor BURSTS -- it wounds everyone in the 3x3 block around where it lands and leaves that
-- whole block ablaze (Fire hazards, exactly as Fireball's). Devastating but scattered -- you choose
-- the zone, the sky chooses the tiles -- so it rewards catching a clustered enemy under the bursts.
--
-- The six IMPACT POINTS are DISTINCT (each is pulled from the pool so no two meteors share a centre),
-- but their bursts freely overlap: a unit caught under two of them is hit twice. That is the spell's
-- ceiling and the reason to aim at a knot of bodies rather than a lone one.
--
-- Geometry: centres are drawn from the 5x5 block around the aim point, so bursts reach one tile
-- further out -- exactly the 7x7 that `aoe` (radius 3, square) paints as the threatened zone.
-- `aoe` is set only for that preview; the strikes pick their own cells below, and off-map picks are
-- harmlessly skipped by fx.unitAt / placeHazard.
return {
    name = "Meteor Storm",
    description = "Calls six meteors onto random tiles in a wide zone, each bursting over a 3x3 block and leaving fire.",
    flavor = "You choose the zone. The sky chooses the tiles, and the sky is not consulted twice.",
    sprite = "assets/items/ability_meteor_storm.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mage",
    price = 620,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 7, -- the most punishing spell, and the slowest to come around again
        channel = 8, -- the longest wind-up: the widest blast telegraphs earliest
        cost = { stat = "mana", amount = 22 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 }, -- per-burst damage = power + the caster's MagicDamage, minus MagicDefense
        aoe = { radius = 3, shape = "square" }, -- paints the 7x7 threatened zone (see note above)
        effect = function(fx)
            -- The 5x5 block of candidate impact points around the aim point.
            local candidates = {}
            for dx = -2, 2 do
                for dy = -2, 2 do
                    candidates[#candidates + 1] = { x = fx.tx + dx, y = fx.ty + dy }
                end
            end
            for _ = 1, math.min(6, #candidates) do
                local c = table.remove(candidates, fx.random(#candidates)) -- distinct impact points
                for dx = -1, 1 do -- the burst: the 3x3 block around the impact
                    for dy = -1, 1 do
                        local u = fx.unitAt(c.x + dx, c.y + dy)
                        if u then fx.damage(u) end
                        fx.placeHazard(c.x + dx, c.y + dy, "hazard_fire")
                    end
                end
            end
        end,
    },
}
