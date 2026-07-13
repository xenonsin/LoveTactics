-- Meteor Storm: the mage marks a wide 6x6 zone and calls down six meteors on random tiles within it.
-- Each impact wounds whoever stands on its tile and leaves the ground ablaze (a Fire hazard, exactly
-- as Fireball does). Devastating but scattered -- you choose the zone, the sky chooses the tiles -- so
-- it rewards catching a clustered enemy where every meteor is likely to land on someone.
--
-- The six strikes fall on DISTINCT tiles (each chosen tile is pulled from the pool so no two meteors
-- share a spot). `aoe` is set only so the targeting UI paints the threatened zone; the real strikes
-- pick their own cells below, and off-map picks are harmlessly skipped by fx.unitAt / placeHazard.
return {
    name = "Meteor Storm",
    description = "Call down six meteors on random tiles in a wide zone, each leaving fire.",
    sprite = "assets/items/ability_meteor_storm.png",
    type = "ability",
    tags = { "fire", "magical" },
    class = "mage",
    price = 620,
    repRank = 4,
    activeAbility = {
        name = "Meteor Storm",
        target = "tile",
        allowOccupied = true,
        range = 4,
        speed = 7, -- the most punishing spell, and the slowest to come around again
        cost = { stat = "mana", amount = 22 },
        power = 8, -- per-meteor damage = power + the caster's MagicDamage, minus MagicDefense
        aoe = { radius = 3, shape = "square" }, -- paints the ~6x6 threatened zone (see note above)
        effect = function(fx)
            -- The 6x6 block of candidate tiles around the aim point.
            local candidates = {}
            for dx = -2, 3 do
                for dy = -2, 3 do
                    candidates[#candidates + 1] = { x = fx.tx + dx, y = fx.ty + dy }
                end
            end
            for _ = 1, math.min(6, #candidates) do
                local c = table.remove(candidates, fx.random(#candidates)) -- distinct tiles
                local u = fx.unitAt(c.x, c.y)
                if u then fx.damage(u) end
                fx.placeHazard(c.x, c.y, "hazard_fire")
            end
        end,
    },
}
