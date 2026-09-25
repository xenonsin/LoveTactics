-- The Birds' Warning: carried by the Lindworm's Heart (data/items/utility/utility_lindworm_heart.lua).
--
-- Dodge's reflex (data/traits/trait_dodge.lua) with the magic let in: `evadesAny` voids the next blow of
-- EITHER kind through Trait.tryEvade, where Dodge's `evadesPhysical` lets a spell through. The birds do not
-- care what is coming, only that something is. Cooldown in ticks, counted down with the rest
-- (Combat.rebase): three turns at Status.TICKS_PER_TURN.
return {
    name = "The Birds' Warning",
    description = "Evade the next attack of any kind, then 3 turns before you can again.",
    cooldown = 15,
    evadesAny = true,
}
