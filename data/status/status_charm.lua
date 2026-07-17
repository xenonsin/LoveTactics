-- Charm: the victim fights for whoever charmed it -- an uncontrollable ally on the caster's side for
-- the duration, planned by the enemy AI (Combat.planEnemyAction reads unit.side), then it reverts.
--
-- The side/control flip and the HP-fraction roll that gates landing it live in the ability effect
-- (data/items/ability/ability_charm.lua): the effect stashes the victim's original side/control on the
-- unit and swaps in the caster's. This status is the TIMER that owns the reversion -- onExpire puts
-- them back.
--
-- A `debuff`, so Cure/Panacea can break the spell and free the victim early -- the fair counterplay
-- (an ally on the charmed unit's former side snaps it out of it). Correctness of the reversion no
-- longer depends on the removal path: Status.remove and Status.cleanse both fire onExpire as the
-- status leaves, so however Charm ends -- countdown, Cure, or a dispel -- the side/control flip is
-- undone and the unit returns to the side it started on.
return {
    name = "Charm",
    abbr = "Chm",
    description = "Charmed: fights for the enemy that turned it, until it comes to its senses.",
    color = { 0.90, 0.45, 0.80 }, -- badge tint (magenta)
    duration = 10, -- ~2 turns at Status.TICKS_PER_TURN: long enough for the victim to actually act
    debuff = true,
    onExpire = function(ctx)
        local u = ctx.unit
        if u._charmSide then
            u.side, u.control = u._charmSide, u._charmControl
            u._charmSide, u._charmControl = nil, nil
        end
    end,
}
