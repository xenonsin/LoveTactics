-- Empowered: a coiled strike. The bearer centred instead of acting (the Gather wait-behavior, granted
-- by a monk charm -- Combat.gather), and the next blow they land carries the stored force. The bonus is
-- the status's MAGNITUDE, folded into the unit's effective ATTACK via combat's flatStat (see
-- Status.statBonus + `magnitudeStat` below), so it shows as its own named row in the damage breakdown
-- exactly as Defending's brace does on the defensive side. The granting charm sets how much through its
-- `waitBehavior.power` (Combat.gather passes it as the magnitude); this `magnitude` here is the fallback
-- for a charm that names none.
--
-- It empowers the DAMAGE stat (physical): Gather is a monk's stance and the fist is a physical blow, so
-- a spell thrown while Empowered is not the thing the body braced for. That is also what keeps the
-- charm on its shelf honest -- it powers the punch it was carried to throw.
--
-- The window ends the moment it is SPENT: onDealDamage strips it the instant the bearer draws blood, so
-- the boost lands on exactly one blow and no more (a 0-damage whiff into an immunity leaves it standing
-- to try again). A generous `duration` is the fallback for a Gather never cashed in, so an unspent
-- stance fades on its own rather than being carried across a whole battle.
return {
    name = "Empowered",
    abbr = "Emp",
    description = "Coiled: the next blow you land carries stored force (+attack, spent on the hit).",
    color = { 0.86, 0.62, 0.30 }, -- badge tint (warm gold, the weak-point flare's family)
    duration = 10,          -- fallback if the stance is never spent (~2 turns); it really ends via onDealDamage
    magnitude = 6,          -- default +attack when the granting charm sets no waitBehavior.power
    magnitudeStat = "damage", -- the flat stat this status's magnitude raises (via Status.statBonus)
    -- Spent on the first blow that draws blood: a connecting strike consumes the stance. A whiff into an
    -- immunity/absorb (amount 0) leaves it standing, so the stored force is never wasted on a hit that
    -- landed for nothing.
    onDealDamage = function(ctx)
        if (ctx.amount or 0) > 0 then ctx.expire() end
    end,
}
