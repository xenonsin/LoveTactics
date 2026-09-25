-- Rapture: Lust in one hook -- it "takes what is not offered" (docs/story.md). Where Charm takes the foe
-- itself, this takes what the foe KEPT: the stamina and mana it was hoarding rather than spending.
--
-- IT WAS LUXURIA'S RULE AND IS NOT ANY MORE. When she became the Queen of the succubi (settled on review
-- 2026-09-25) her fight became her army, and this left her kit for its own piece: the Saint's Chalice
-- (data/items/utility/utility_saints_chalice.lua). The review asked for it back "as an aoe drain", so it
-- no longer drinks from one body: every blow draws off the reserves of the foe it lands on AND of every
-- foe standing beside that one, and half of what it took comes back to the bearer as health.
--
-- The counterplay is still the sin stated as tactics: SPEND, and do not bunch up. A company that pours its
-- reserves out each turn has nothing held back to find; one clustered around the body being hit feeds the
-- bearer three and four times over. And the one unit it can never draw from is Xin
-- (data/traits/trait_devotion_unbidden.lua), whose Unbidden rule this hook checks and passes over.
--
-- Per body it takes less than the old single-target rule did (12 each) and still more than the Unasked
-- (trait_unasked, 8 each), which is the ordering tests/greed_lust_circle_spec.lua holds.
return {
    name = "Rapture",
    description = "Draws off the stamina and mana held back by the foe you hit and every foe beside it, "
        .. "and takes half into you as health.",
    stamina = 10, -- reserve seized from each pool, per body caught
    mana = 10,
    onCast = function(ctx)
        local centre = ctx.unitAt(ctx.tx, ctx.ty)
        if not (centre and centre.alive) then return end
        -- WHOSE the body is, not which side it is standing on: a foe this same cast just Charmed is on
        -- the bearer's side by the time this hook runs, and it is still a foe (Status.ownSide).
        local Status = require("models.status")
        local Trait = require("models.trait")
        local mine = Status.ownSide(ctx.unit)
        if Status.ownSide(centre) == mine then return end
        local taken, spared = 0, false
        for _, u in ipairs(ctx.unitsNear(centre.x, centre.y, 1)) do
            if u.alive and u ~= ctx.unit and Status.ownSide(u) ~= mine then
                -- A will that gave everything away holds nothing back to seize (Xin's Unbidden rule).
                if Trait.has(u, "trait_devotion_unbidden") then
                    spared = true
                else
                    taken = taken + ctx.drain(u, "stamina", ctx.def.stamina) + ctx.drain(u, "mana", ctx.def.mana)
                end
            end
        end
        if spared then
            ctx.log("action", "One of them has held nothing back.")
        end
        if taken > 0 then
            ctx.heal(ctx.unit, math.floor(taken / 2 + 0.5))
            ctx.log("action", string.format("%s takes what was not offered.",
                (ctx.unit.char and ctx.unit.char.name) or "The bearer"))
        end
    end,
}
