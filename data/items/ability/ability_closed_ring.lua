-- The Closed Ring: eight tiles of standing barrier raised in a square around one cell. Whatever is
-- inside stays inside, and whatever is outside stays out.
--
-- A PRISON RATHER THAN A WALL, which is the difference between this and every other barrier here.
-- Summon Wall and Riven Ground both screen a LANE: they say "not through here", and the answer is to
-- go round. A ring has no round. A body caught in one has to break its way out through a wall segment
-- -- which takes real turns -- while the rest of the field carries on without it.
--
-- What it is actually for is subtraction. The enemy's heaviest piece, or its healer, or the one
-- summoner holding four creatures on the board, is simply not in the battle for two or three turns,
-- and unlike a stun it cannot be cleansed, dispelled off, or waited out on a short clock. The party
-- fights four instead of five, wins that, and then opens the box.
--
-- The corollary, and the reason it is not simply the best control in the game: NOTHING GETS IN EITHER.
-- A ringed foe cannot be shot, charged or healed by anybody, so this is a spell that removes a piece
-- from BOTH sides' reach. Ringing a target you were about to kill is the classic way to waste a turn
-- and save an enemy's life.
--
-- Eight segments rather than a filled square: the centre cell is deliberately left open, because that
-- is where the body is. Wall.place refuses an occupied tile anyway, so a ring cast on empty ground and
-- a ring cast around a foe produce the same eight segments -- and the empty-ground version is the
-- knight's other use for it, closing a doorway before anybody has walked through.
--
-- ADJACENCY: a `shield` beside it, like the Grasping Hollow -- and, like the hollow, that competition
-- with the guard redirects for the cells around the shield is the loadout decision this item is really
-- selling.
return {
    name = "The Closed Ring",
    description = "Raises a ring of barrier around one tile: nothing walks in, and nothing walks out.",
    flavor = "The Bastion's oldest sentence, carved over the cells: we shall hold. It was never only about gates.",
    sprite = "assets/items/ability_closed_ring.png",
    type = "ability",
    tags = { "earth" },
    class = "knight",
    price = 480,
    repRank = 4,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 4,
        requiresSight = true,
        speed = 5,
        channel = 3, -- a turn's warning: the ringed piece gets one chance to step out of the box
        cost = { { stat = "mana", amount = 18 }, { stat = "stamina", amount = 6 } },
        support = true,
        requiresAdjacent = { tag = "shield" },
        effect = function(fx)
            -- The eight cells around the aimed one. Nothing is placed on the centre: that is where the
            -- prisoner is, and Wall.place would refuse it anyway -- so writing the loop this way makes
            -- the intent visible rather than relying on a refusal to express it.
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then
                        fx.placeWall(fx.tx + dx, fx.ty + dy, "illusory_wall",
                            { health = 22 + 2 * fx.level, duration = 16 + fx.level })
                    end
                end
            end
        end,
    },
}
