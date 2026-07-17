-- Choking fumes: the ground a Censer of Ashes carries, and the same family read from the other side.
-- Where Incense (data/hazards/hazard_incense.lua) blesses the ground it walks, this chokes it --
-- everyone in the cloud EXCEPT the bearer's own side takes the Poison (data/status/status_poison.lua).
--
-- Both are the Cathedral's. A faith with a punitive half is exactly what lust's shelf is, and the censer
-- does not change between the two -- only the voice it is swung in (see docs/classes.md).
--
-- What it changes about how the weapon is played is the whole point of it. A supporting weapon normally
-- wants you behind your line; this one only works where the enemy is, so carrying it means walking your
-- priest INTO them and staying there. The damage is the walk.
--
-- Poison DOES declare `lingers` (unlike the Blessing its counterpart grants), so it is not zone-bound:
-- what the cloud hands out travels with the victim and keeps burning after they flee it. That asymmetry
-- is deliberate -- you can walk out of a blessing, but you cannot walk out of a lungful.
return {
    name = "Choking Fumes",
    description = "A censer's poisoned smoke: foes standing within are Poisoned.",
    sprite = "assets/hazards/choking.png",
    tags = { "poison" },
    duration = 12,           -- as Incense: renewed each beat by the censer, and gone within a turn without one
    disposition = "hostile", -- the enemy AI steps around it, which is itself a way to push a line
    onEnter = function(ctx)
        -- Sided to the bearer, so the censer's own line breathes freely: whoever swings it knows what is
        -- in it, and the faithful are not the ones being purged. Mirror of a Sanctuary's ally check.
        if ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_poison", { magnitude = ctx.amount })
    end,
}
