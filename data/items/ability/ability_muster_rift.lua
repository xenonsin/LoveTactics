-- The Muster Rift: the knight calls the company to them. Every ally on the field is set down on open
-- ground beside the caster, wherever they were standing a moment ago.
--
-- BOARD-SCALE REPOSITIONING, and nothing else in the game does it. Every other movement effect here
-- moves ONE body a short way: a blink, a shove, a pull, a swap, a charge. This moves a WHOLE SIDE, any
-- distance, in one action -- which is not a bigger version of those, it is a different kind of thing.
-- A party that has been split by terrain, or strung out by a chase, or half-caught in a fire, is a
-- party that is losing; this un-loses it in one turn.
--
-- Which is why it is the most expensive knight item on the shelf, why it channels for two turns before
-- it lands, and why the enemy gets to watch the whole thing coming. The wind-up is the counterplay:
-- everyone can see where the muster is going to be, and the enemy has a turn to be standing there when
-- it arrives. Calling your scattered line into the middle of the enemy's is a legal way to lose.
--
-- IT MOVES EVERY ALLY, including the ones who were exactly where you wanted them. There is no version
-- that picks and chooses -- a muster is a muster. That is what makes it a decision rather than a free
-- convenience: the archer who had a good line, the priest who was safely out of reach, the summon that
-- was holding a doorway all come too.
--
-- ADJACENCY: a `banner` item beside it. You cannot call a company that has nothing to form up on, and
-- the banner slot is one the warlord kit already wants -- so a knight who musters is a knight who has
-- committed their grid to being the anchor rather than the wall.
return {
    name = "The Muster Rift",
    description = "Sets down every living ally on open ground beside the caster.",
    flavor = "Forty-one held the gate. The other thing they were very good at was arriving.",
    sprite = "assets/items/ability_muster_rift.png",
    type = "ability",
    tags = { "arcane" },
    class = "knight",
    price = 540,
    repRank = 4,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        channel = 4, -- two turns of everyone watching where the muster will be
        cost = { stat = "mana", amount = 26 },
        support = true,
        requiresAdjacent = { tag = "banner" },
        effect = function(fx)
            -- Radius 8 rather than a true board sweep: fx.unitsNear is the only ally scan the effect
            -- context offers, and 8 comfortably covers every arena this game generates. Stated as a
            -- number rather than pretending to be unlimited, because a number is honest and a lie
            -- about reach is the kind of thing that stops being true when the arenas get bigger.
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 8)) do
                if u.side == fx.user.side and u ~= fx.user then
                    -- Open ground BESIDE the caster, one body at a time -- so each arrival takes a
                    -- fresh free tile and the muster forms a ring rather than stacking. A tile that
                    -- cannot be found (the caster is hemmed in) simply leaves that ally where they
                    -- were, which is the right failure: a rift that dropped people into walls would
                    -- be a much worse spell than one that occasionally cannot fit everybody.
                    local tx, ty = fx.openTileNear(fx.user.x, fx.user.y)
                    if tx then fx.teleport(u, tx, ty) end
                end
            end
        end,
    },
}
