-- The Unspent Heart: a vast slow recovery that shuts off the moment anybody touches its wearer, and
-- takes a while to come back.
--
-- Sustain priced on BEING LEFT ALONE, which is a thing this game had no way to sell. Every other
-- recovery in the catalog pays out on the clock regardless (staminaRegen, a Sanctuary's Regeneration,
-- the priest's presence), so all of them are worth the most to the character being focused -- which
-- is backwards, because that character is also the one the enemy has already decided to kill. This
-- pays the opposite unit: the flanker nobody is looking at, the knight who broke off, the wounded
-- fighter who spent two turns walking the long way round.
--
-- Implemented as a cooldown rather than a status, deliberately. A status would be visible on the badge
-- row as a debuff the enemy could read and count down; a cooldown is the wearer's own bookkeeping, and
-- the enemy's information is exactly what it should be -- "I hit them recently" -- with no timer
-- attached to it. It also means a Cure cannot restart the heart, which would be a strange thing for a
-- cure to do.
--
-- ONE HOOK, and that is the whole file. The RECOVERY lives where every other recovery in this game
-- lives -- Combat.regenerate, which runs on the shared clock and already knows how to pay a rate per
-- elapsed tick. All this trait does is SHUT it: any wound at all, from anyone, including a poison tick
-- or a fire, puts "unspent_heart" on cooldown, and the regen loop simply declines to pay while that
-- timer stands. Splitting it that way is why there is no per-tick trait hook and why there should not
-- be one (see models/trait.lua): a reflex is a thing that answers an event, and the clock is not one.
return {
    name = "Unspent Heart",
    description = "Mends hard while untouched; any wound stops it for a while.",
    magnitude = 25, -- ticks the heart stays shut after a wound (~5 turns)
    onDamaged = function(ctx)
        ctx.setCooldown("unspent_heart", ctx.def.magnitude or 25)
    end,
}
