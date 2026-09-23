-- CONSTRICTOR'S DUE: what an Elder does with a thing she has already caught. The bearer's blows land
-- harder on anything that cannot leave.
--
-- THE PAYOFF HALF OF ONE CIRCLE'S PAIR. utility_the_slow_circle -- the Lamia's own drop -- puts a
-- string on somebody; this bills for it. Neither is worth much alone and both fall off the same
-- stratum, which is what a drop table should feel like: the floor teaches you a rule in two halves and
-- sells you both of them.
--
-- THREE STATUSES, NAMED, AND THE LIST IS THE DESIGN. What counts is "cannot leave", not "cannot act":
--
--   status_coiled   pays to leave the circle (the lamia's own, and this item's first customer)
--   status_root     cannot move at all, and cannot be moved
--   status_mired    movement costs doubled -- the Warden's hold, which is why it shelves there
--
-- Freeze, Stun and Sleep are DELIBERATELY ABSENT even though they are the harder control. A charm that
-- paid out on every disabled body would be "hit the helpless harder", which is trait_executioners_eye's
-- space and is a far broader item than this -- and it would stop being about a serpent. Held is not the
-- same as helpless, and only one of the two is what a constrictor is for.
--
-- A FLAT BONUS RATHER THAN A MULTIPLIER, on the shelf's own convention (trait_empty_vessel's 8 against
-- a spent caster, the Duelist's 6 in a one-on-one). A multiplier would scale with the weapon and turn
-- this into a greatsword tax; the flat number is worth proportionally more to the small fast blows
-- that a held target invites, which is the right way round.
--
-- A PURE QUERY. Trait.outgoingDamageBonus runs this on every damage PREVIEW as well as every blow, so
-- it must not spend, mutate or begin a beat -- and because both paths sum it, the number the hover
-- promises is the number that lands.
return {
    name = "Constrictor's Due",
    description = "Increase damage against anything that cannot leave.",
    magnitude = 7, -- flat pre-mitigation bonus against a held body
    damageBonusVs = function(ctx)
        local held = ctx.hasStatus(ctx.target, "status_coiled")
            or ctx.hasStatus(ctx.target, "status_root")
            or ctx.hasStatus(ctx.target, "status_mired")
        if not held then return 0 end
        return ctx.def.magnitude or 7
    end,
}
