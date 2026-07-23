-- Riven Ground: the mage opens a seam of standing rock across the field. Five tiles of it, running
-- perpendicular to the cast, blocking movement and sight both. It deals nothing at all.
--
-- The longest wall in the game and the only one that is purely a wall. Summon Wall raises three tiles
-- of conjured illusion that a Dispel takes down at a stroke; this is stone, it is five wide, and the
-- only way through it is to break it or go round. That length is the whole item: three tiles screens a
-- lane, and five tiles CUTS A BOARD IN HALF, which is a categorically different thing to be able to do.
-- Half an enemy line arriving two turns after the other half is not a fight the party has to win twice
-- -- it is two fights the party wins separately.
--
-- Deliberately dealing zero damage, and priced as if it dealt a great deal. Pride's shelf is elements
-- and wind-ups and remaking the ground itself (docs/classes.md), and this is the third of those with
-- the first two deliberately withheld -- the mage's answer to a losing engagement is not a bigger
-- fireball, it is to decide that half the enemy is not in this engagement.
--
-- ADJACENCY: an `earth` item must sit beside it. The seam is drawn out of the ground, and the grid has
-- to hold something that knows the ground -- which in practice means the Quicksand stone or the earth
-- elemental's summoning charm, and which means this spell competes for the slots those want.
return {
    name = "Riven Ground",
    description = "Splits the field with a five-tile ridge of stone that blocks movement and sight.",
    flavor = "Not a wall. The Arcanum did not build anything -- it merely stopped agreeing that the ground was flat.",
    sprite = "assets/items/ability_riven_ground.png",
    type = "ability",
    tags = { "earth", "magical" },
    class = "mage",
    price = 460,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- aim past a body; the occupied tiles are skipped by Wall.place
        range = 5,
        requiresSight = true,
        speed = 5,
        channel = 3,
        cost = { stat = "mana", amount = 22 },
        support = true, -- it lands no damage: reads green, and the AI weighs it as zoning
        effect = function(fx)
            -- Perpendicular to the caster's line, exactly as Summon Wall's is and for the same reason:
            -- aimed past a foe, the seam screens the lane BETWEEN you rather than running along it.
            local dx, dy = fx.tx - fx.user.x, fx.ty - fx.user.y
            local ax, ay
            if math.abs(dx) >= math.abs(dy) then ax, ay = 0, 1 else ax, ay = 1, 0 end
            -- Five wide against Summon Wall's three, and tougher per segment, and it climbs with the
            -- forge on both axes: a ridge you can break through in one turn is a ridge that bought
            -- nothing.
            for i = -2, 2 do
                fx.placeWall(fx.tx + ax * i, fx.ty + ay * i, "illusory_wall",
                    { health = 28 + 3 * fx.level, duration = 20 + fx.level })
            end
        end,
    },
}
