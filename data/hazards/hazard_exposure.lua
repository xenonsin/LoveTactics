-- The Coveted Blood's cloud: the ground the alchemist carries with it, in which enemy flesh will not
-- close (data/status/status_exposed.lua). Everyone in it EXCEPT the bearer's own side is Exposed.
--
-- Mechanically this is Choking Fumes (data/hazards/hazard_choking.lua) with the damage taken out, and
-- the resemblance is worth reading rather than hiding: both are a sided cloud that walks with whoever
-- carries it, and both mean the same thing about how their item is played -- it only works where the
-- enemy is, so carrying one is a commitment to standing in the wrong place. The difference is that the
-- censer's cloud kills people and this one does not kill anybody at all. It only makes your line's
-- arrows worth more, which is the entire distinction between lust's punitive half and envy.
--
-- Zone-bound, because Exposed declares no `lingers`: step out of the cloud and it lifts at once. No
-- tick, no damage, no spread -- there is nothing in here but a condition on somebody else's arithmetic.
return {
    name = "Coveted Blood",
    description = "A cloying haze: foes standing within take extra damage from piercing hits.",
    sprite = "assets/hazards/exposure.png",
    tags = { "poison" },
    duration = 12,           -- as Incense: renewed each beat by the bearer, and gone within a turn without one
    disposition = "hostile", -- the enemy AI steps around it, which is itself a way to move a line
    onEnter = function(ctx)
        -- Sided to the bearer, so the alchemist's own party is never the one being opened up. Mirror
        -- of the Choking Fumes' ally check, and of a Sanctuary's before it.
        if ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_exposed", { magnitude = ctx.amount })
    end,
}
