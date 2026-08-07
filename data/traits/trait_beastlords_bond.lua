-- Beastlord's Bond: the standing rule of the charm of the same name
-- (data/items/utility/utility_beastlords_bond.lua). Every time the bearer acts, the creatures they have
-- put on the field and that are standing near them are mended a little.
--
-- WRITTEN AGAINST `summoned`, NOT AGAINST BEASTS. That is the whole point of the item and worth being
-- explicit about: the hook asks whether a unit is a conjuration of the BEARER'S, and never what kind.
-- So it mends a Beastmaster's wolf and hawk and a Summoner's elementals with one rule, and the two
-- shelves' builds get the same sustain out of it. A discipline field can only ever name one owner
-- (docs/classes.md), so this charm lives on the Beastmaster's shelf -- but nothing in its behaviour
-- knows that, which is what lets a conjuring build of either kind carry it and have it mean the same
-- thing. Anyone carries anything; this is what that rule is for.
--
-- Hangs on onCast (see models/trait.lua) because there is no per-turn trait hook -- the bearer FINISHING
-- an action is the closest thing to a heartbeat a reflex can hang on. In practice that reads correctly:
-- the pack is steadied by its handler doing something, not by standing there.
--
-- `radius` is the leash, and it is a tactical statement rather than a limit for its own sake: your
-- creatures are mended where you can see them. A summoner who fields elementals and then walks away
-- from them gets nothing, and a beastmaster who fights beside the pack gets everything -- which is the
-- posture both disciplines are supposed to want, and the one this game's area damage argues against.
--
-- Only the bearer's OWN conjurations (`summoner == bearer`), so a party with two summoners does not
-- quietly cross-heal, and the bearer itself is skipped -- a handler is not their own beast.
return {
    name = "Beastlord's Bond",
    description = "Every action you take mends the creatures you summoned that are standing near you.",
    magnitude = 4, -- health returned to each creature, per action
    radius = 3,    -- the leash: how far the bond reaches
    onCast = function(ctx)
        local bearer = ctx.unit
        if not bearer then return end
        local reach = ctx.def.radius or 3
        for _, u in ipairs(ctx.unitsNear(bearer.x, bearer.y, reach)) do
            if u ~= bearer and u.alive and u.summoned and u.summoner == bearer then
                ctx.heal(u, ctx.def.magnitude or 4)
            end
        end
    end,
}
