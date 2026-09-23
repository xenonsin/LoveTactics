-- Coiled: bound to the thing that bit you. End a turn outside its circle and it closes on you.
--
-- THE LUST CIRCLE'S THIRD VERB, and the one it did not have. The flock decides where your body is; the
-- Matriarch decides what it does; this decides that it does not get to be anywhere else. Where Root
-- takes the turn, this takes the GROUND -- you may walk wherever you like and the walking is what
-- costs, which is why it is a price rather than a lock and why the two sit on the same body without
-- being the same rule (data/characters/character_lamia.lua).
--
-- ---------------------------------------------------------------------------
-- IT IS ACEDIA'S OATH READ FROM THE OTHER END, AND THE DIFFERENCE IS THE POINT
-- ---------------------------------------------------------------------------
--
-- `status_sworn` binds two of YOUR OWN bodies to each other and bills whichever of them stands alone
-- (data/status/status_sworn.lua). It is Sloth's whole identity: a formation that cannot afford to move.
-- This binds one of yours to ONE OF HERS. Same shape of check, opposite sentence --
--
--   SWORN    stay together, or it bites.         (a company that cannot spread out)
--   COILED   stay with HER, or it bites.         (a body that cannot get away)
--
-- -- and the reason both can exist is that they pull in different directions: Sworn punishes a company
-- for coming apart, Coiled punishes one member for not coming apart from the party. Put them on one
-- board and the player is pulled two ways at once, which is what a fourteenth floor is for.
--
-- AND THIS ONE DIES WITH THE ONE WHO CAST IT, where the oath explicitly does not. That is not an
-- inconsistency, it is each circle's law: Sloth's oath "does not release you for having failed it",
-- and every control effect in LUST ends with the body holding it -- a charm when its charmer leaves
-- the field (Combat.releaseCharmedBy), a jeer when its taunter falls (status_taunt's onTick), and this
-- when the serpent does. Cut the one doing it is the whole counterplay of this stratum, and a tether
-- that outlived its tetherer would be the one place it did not hold.
--
-- THE CIRCLE IS TWO TILES, measured the way a board measures a reach rather than the way an oath
-- measures a shoulder. Sworn uses orthogonal adjacency because it is about standing in the line beside
-- somebody; this is about being inside something's coils, so it is Chebyshev and it is wider than arm's
-- length. Two is deliberately further than the serpent's own bite (Strangleknot reaches one): the
-- circle you must stay inside is bigger than the circle you get hurt in, so obeying the tether is not
-- the same as standing in reach of the fangs, and there is a ring of tiles that satisfies both.
--
-- RAW, LIKE THE OATH. Armour turns a fang; it does nothing about the length of a rope.
--
-- `perTile` IS NOT SET HERE and that is the alpha's whole escalation: an Elder's coil stamps it on
-- application (data/traits/trait_the_long_coil.lua) so her bite grows with the distance you managed to
-- put between you. A plain lamia's is flat, and reads as flat.
return {
    name = "Coiled",
    abbr = "Cld",
    description = "Coiled: end your turn away from the serpent that bound you and it closes.",
    color = { 0.502, 0.416, 0.612 }, -- badge tint (a dim serpent violet, off Sworn's liturgical one)
    duration = 999,      -- it does not wear off; it lasts as long as the thing holding it does
    hideDuration = true, -- the countdown says nothing -- where you are standing is the whole story
    debuff = true,       -- Cure cuts the tether, which is the other way out
    magnitude = 5,       -- damage for a turn ended outside the circle; an Elder's relic scales it
    radius = 2,          -- the coil's circle, Chebyshev (see the header on why it is wider than a bite)
    -- THE SLOPE MAY DOUBLE THE TOLL AND NO MORE. Measured before this existed, an Elder's tether at
    -- five tiles billed 17 raw a turn -- a full melee hit from her, unmitigated, on top of the melee
    -- hits she was already throwing, and more than Acedia's own oath bills from a general. A curve
    -- with no ceiling stops being a price and becomes a second attack that the victim delivers to
    -- itself. The cap is stated as a MULTIPLE of the flat bite rather than as a number so it cannot
    -- drift away from it (the Assayer's `ceiling` makes the same argument about a rich purse).
    --
    -- What it means on the board is a target: running doubles what the coil costs you and then stops
    -- mattering, so there is a distance past which the company may spread out freely -- which is the
    -- difference between a fight it can plan around and one it can only lose slowly.
    maxScale = 2,
    onTurnEnd = function(ctx)
        local coiler, unit = ctx.status.coiler, ctx.unit
        -- The serpent is gone, so the tether is gone. Deliberately the opposite of Sworn, which holds
        -- you to a corpse -- see the header. Expiring runs no reversion; there is nothing to undo.
        if not (coiler and coiler.alive) then ctx.expire() return end

        local radius = ctx.status.radius or 2
        local gap = math.max(math.abs(coiler.x - unit.x), math.abs(coiler.y - unit.y))
        if gap <= radius then return end

        -- THE ALPHA'S HALF: every tile past the circle is worth another bite, clamped to `maxScale`
        -- times the flat toll (see above). Flat for a plain lamia, which never stamps `perTile` at
        -- all -- and the clamp is a no-op for it, so the cheap body's arithmetic stays the one number
        -- its badge promises.
        local flat = ctx.magnitude
        local amount = flat + ((ctx.status.perTile or 0) * (gap - radius))
        local ceiling = flat * (ctx.status.maxScale or ctx.status.def.maxScale or 2)
        if amount > ceiling then amount = ceiling end
        ctx.damage(unit, amount, { "dark" }, { raw = true })
        ctx.log("action", string.format("%s is too far from %s, and the coil closes.",
            (unit.char and unit.char.name) or "Unit",
            (coiler.char and coiler.char.name) or "the serpent"), { unit, coiler })
    end,
}
