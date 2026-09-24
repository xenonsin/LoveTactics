-- Trophy Cord: a tooth for every kind of thing you have killed on this trip. +2 Damage for each different
-- kind of body the bearer has felled since the company last came through the Gate, up to +10. Rengar's
-- Bonetooth Necklace, by way of the Sabertooth (round three of "The Sabertooth" review, doubled from a
-- +1 / +5 cord that was "too underpowered").
--
-- IT COLLECTS, WHICH IS GLUTTONY'S VERB. A company that farms one fight fills one knot; a company that
-- goes looking for the wood's other animals fills five. The kinds are blueprint ids (`fallen.char.id`), so
-- a wolf and the alpha leading it are two knots, and so are a grunt and the White Wolf.
--
-- THE COUNT LIVES ON THE PIECE (`item.trophies`, a set of body ids), because the promise is the bearer's
-- and a trip spans many fights and many saves: models/save.lua writes it, and Player.clearTrophies --
-- hung on Player.unpack, which both of the Gate's exits already call -- empties it.
--
-- "YOU KILLED" IS `lastAttacker`, the same stamp killUnit already names a killer by. A foe finished by a
-- trap or a burn has no killer and fills nothing.
local PER, CAP = 2, 10

return {
    name = "Trophy Cord",
    description = "+2 Damage for each different kind of foe you have killed this trip, up to +10.",
    per = PER,
    cap = CAP,
    onAnyDeath = function(ctx)
        local fallen, unit, item = ctx.fallen, ctx.unit, ctx.trait and ctx.trait.item
        if not (item and fallen and fallen.lastAttacker == unit and fallen.side ~= unit.side) then return end
        local kind = fallen.char and fallen.char.id
        if not kind then return end
        item.trophies = item.trophies or {}
        item.trophies[kind] = true
    end,
    live = function(ctx)
        local item = ctx.trait and ctx.trait.item
        if not (item and item.trophies) then return nil end
        local kinds = 0
        for _ in pairs(item.trophies) do kinds = kinds + 1 end
        if kinds == 0 then return nil end
        return { damage = math.min(CAP, PER * kinds) }
    end,
}
