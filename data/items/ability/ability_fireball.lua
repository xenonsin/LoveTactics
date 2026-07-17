return {
    name = "Fireball",
    description = "Bursts on a tile for fire damage in an area, and leaves the ground burning.",
    flavor = "The Arcanum's loudest argument, and the one it is proudest of winning.",
    sprite = "assets/items/ability_fireball.png",
    type = "ability",
    tags = { "fire", "magical" }, -- the "magical" tag routes damage to magicDamage/magicDefense
    class = "mage",
    price = 350,
    repRank = 3,
    activeAbility = {
        -- Hurled at a CELL, not a single foe: aim it at any walkable tile in range -- empty ground,
        -- an enemy, or one of your own (allowOccupied) -- and it bursts there, sweeping everyone in
        -- the blast. Aiming a spot rather than a body lets you catch a cluster, or lead a foe that is
        -- about to move (the wind-up gives them a turn to walk INTO or out of the marked tiles).
        target = "tile",
        allowOccupied = true,
        range = 3,
        requiresSight = true, -- must see the target cell: terrain cover blocks the throw
        speed = 4, -- powerful but slow
        channel = 2, -- winds up before it lands: foes get a turn or two to leave the blast
        cost = { stat = "mana", amount = 12 },
        damage = { 8, 9, 10, 10, 11, 12, 13, 14, 14, 15, 16 }, -- per-target damage = power + the caster's MagicDamage, minus MagicDefense
        -- Bursts on impact: a 1-tile radius around the aimed cell, corners included (a 3x3 square).
        -- The targeting UI reads this to paint the affected tiles red before you commit.
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            -- Sweep every unit caught in the blast -- allies included, so mind your own line.
            -- fx.aoeUnits reads the `aoe` above, so the hit set always matches the red footprint.
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
            -- The blast leaves the ground ablaze: a Fire hazard on every scorched tile (the same
            -- `aoe` footprint). It burns whoever enters, spreads into forest, and lingers a few turns.
            -- A more-forged Fireball sears hotter (Burn base 4/turn, +1 per level) and burns longer.
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { amount = 4 + fx.level, duration = 15 + fx.level })
            end
        end,
    },
}
