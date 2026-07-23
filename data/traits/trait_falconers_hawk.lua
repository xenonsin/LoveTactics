-- Falconer's Hawk: the glove's innate. It marries the two verbs gluttony's shelf is built on -- beasts
-- and the mark (docs/classes.md) -- into one opener. At the first bell a hawk drops onto a tile beside
-- the bearer, and the nearest foe on the field is Marked: the bird has already picked out the quarry
-- before anyone has moved.
--
-- WHY A SEPARATE ANIMAL from the wolf (data/traits/trait_wolf_companion.lua): the wolf is a body that
-- fights beside you; the hawk is a SPOTTER. It fields the setup the rest of the shelf pays off -- a
-- Marked foe is one the Marksman's Lens shoots harder, the Executioner's Eye stacks control onto, and
-- the whole party's follow-up lands into. The bird's own blows are an afterthought (character_hawk is
-- fragile and hits soft); what it is FOR is that first mark, handed to you free of a turn or a cast.
--
-- Summoned `noClaim` (models/trait.lua), so it does not lock a granting active -- the glove is a pure
-- passive charm with no ability of its own. Stashed as `unit.hawkCompanion` on the same convention the
-- wolf uses, in case a later relic wants to read "is the hawk still up?". Sustained by the bearer: it
-- falls if the bearer does, and cannot be resummoned -- one hawk, granted once, like the wolf.
--
-- The mark goes on the NEAREST living foe, chosen at the opening so it is deterministic and the player
-- can read it: the bird stoops on the closest threat. If the field somehow holds no foe (an empty
-- opener), it simply arrives and waits.
return {
    name = "Falconer's Hawk",
    description = "A hawk starts at your side and Marks the nearest foe at the opening bell.",
    onCombatStart = function(ctx)
        local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
        if x then
            ctx.unit.hawkCompanion = ctx.summon("character_hawk", x, y, { noClaim = true })
        end
        -- Stoop on the closest quarry: the nearest living foe, marked at the opening.
        local best, bestDist
        for _, u in ipairs(ctx.combat.units) do
            if u.alive and u.side ~= ctx.unit.side then
                local d = math.abs(u.x - ctx.unit.x) + math.abs(u.y - ctx.unit.y)
                if not bestDist or d < bestDist then best, bestDist = u, d end
            end
        end
        if best then
            ctx.applyStatus(best, "status_mark")
            ctx.log("action", string.format("%s's hawk marks the quarry.",
                (ctx.unit.char and ctx.unit.char.name) or "The falconer"))
        end
    end,
}
