-- A mace, so it shoves (docs/weapons.md): the blow drives the target back and a collision hurts
-- everything in it. Its extra is the inversion of the family's own bargain -- it shoves only ONE tile,
-- and doubles what the collision is worth.
--
-- The iron mace buys travel: two tiles of it, and the damage scales with how much of that travel got
-- taken away. This one has almost no travel to lose, so it is worth nothing in the open field and
-- enormous against a wall, a board edge, or a second body. It is the mace for a corridor.
--
-- Which makes it the entry-rank mace that teaches the family's actual lesson. A new player swings an
-- Iron Mace at open ground, watches a foe slide two tiles and take almost nothing, and concludes maces
-- are bad. Swing this at a man with a wall behind him and the point lands immediately.
return {
    name = "Bell-Hammer",
    description = "Drives the target back a single tile, and a collision hurts twice as much.",
    flavor = "Short in the handle, unkind about walls. The Bastion's armourers call it the second opinion.",
    sprite = "assets/items/bell_hammer.png",
    type = "weapon",
    tags = { "mace", "impact", "physical", "melee" },
    class = "knight",
    price = 210,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 8 },
        -- Under an iron mace's: the collision is where this weapon keeps its damage.
        damage = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 },
        effect = function(fx)
            -- One tile of travel, and the collision priced at double the swing. The shove rides IN the
            -- blow so a killing hit still throws the body first (the rule the Iron Mace's header sets
            -- out and every mace here follows).
            fx.damage(fx.target, { knockback = { distance = 1, amount = (fx.amount or 0) * 2 } })
        end,
    },
}
