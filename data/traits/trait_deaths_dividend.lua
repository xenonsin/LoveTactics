-- Death's Dividend: the standing rule of the Charnel Reliquary (data/items/utility/utility_charnel_reliquary.lua).
-- Every real body that falls within reach of the bearer feeds their craft -- a permanent lift to Magic
-- Damage for the rest of the battle, stacking with each death. The necromancer does not merely raise the
-- dead; they are STRENGTHENED by dying, whoever it is that dies.
--
-- Hangs on onAnyDeath, the one broadcast hook (see models/trait.lua) -- it fires on everyone still
-- standing when a combatant drops, never on the corpse, and never for a summon or a decoy leaving the
-- field. So a summoner farming its own conjurations gets nothing, and neither does the bearer's own raised
-- zombie rotting away: it is the death of a REAL body nearby that pays the dividend, friend or foe alike --
-- "whose death was it?" is a question this reflex deliberately never asks.
--
-- `magnitude` is the reach in tiles: a death farther off than that is somebody else's harvest.
return {
    name = "Death's Dividend",
    description = "Every real body that falls near you permanently raises your Magic Damage for the battle.",
    magnitude = 3, -- tiles: a body must fall within this range of the bearer to feed them
    onAnyDeath = function(ctx)
        local fallen = ctx.fallen
        if not fallen then return end
        local reach = ctx.def.magnitude or 3
        local d = math.abs(ctx.unit.x - fallen.x) + math.abs(ctx.unit.y - fallen.y)
        if d > reach then return end
        ctx.addBonus("magicDamage", 2) -- for the rest of the battle; written to unit.bonus, never the blueprint
        ctx.log("action", string.format("%s draws power from the fallen.",
            (ctx.unit.char and ctx.unit.char.name) or "The necromancer"))
    end,
}
