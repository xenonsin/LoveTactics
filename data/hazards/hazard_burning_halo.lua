-- A Burning Halo: the ring of white fire a certain relic throws off. Enemies standing in it burn and
-- are blinded; allies pass through it untouched.
--
-- Two statuses from one zone, and they are chosen to answer each other's weakness. Burn is a clock: it
-- pays out whether or not the halo's wearer does anything, so the relic is worth carrying by a
-- character who spends their turns walking. Blind is a REACH cut (Status.rangeMalus): it shortens
-- every ability a victim owns, so the archers and casters caught in the ring have to step out before
-- they can shoot at all -- which is the same as saying the halo pushes them, without shoving anybody.
--
-- The pairing is what makes it a front-line item rather than a damage item. The burn asks you to stand
-- in the enemy's line; the blindness is what makes standing there survivable, because everything that
-- would shoot you has to leave first.
--
-- Burn `lingers` (it is carried out of the fire, by its own rule) and Blind does not, so walking clear
-- of the halo stops the blindness at once and takes the flames with you. Two statuses, two different
-- endings, neither of them written here -- see the contract at the top of models/hazard.lua.
return {
    name = "Burning Halo",
    description = "A ring of white fire: enemies in it burn, and cannot see far enough to shoot.",
    sprite = "assets/hazards/burning_halo.png",
    tags = { "fire" },
    duration = 6,
    disposition = "hostile",
    dousedByTags = { "water" }, -- rain smothers the ring, as it smothers every other fire
    onEnter = function(ctx)
        if ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_burn", { magnitude = ctx.amount })
        ctx.applyStatus(ctx.unit, "status_blind")
    end,
}
