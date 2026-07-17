-- Counter Magic: a standing reflex that unravels a single-target spell aimed at its bearer, completely,
-- for the price of mana and a cooldown. The blow deals nothing -- no damage, no rider status, nothing
-- lands at all (Trait.tryCounterMagic, consulted from Combat.dealDamage before the cast reaches armor).
--
-- The counterspell's classic bargain, and the reason it is priced flat rather than scaled: it does not
-- care how big the spell was. It eats a Meteor exactly as it eats a spark, for the same 14 mana. So
-- the trait is not "a ward"; it is a STANDING THREAT, and the interesting play is on the other side of
-- it. A mage looking at a counter-warded knight has to decide whether to spend its big cast baiting
-- the reflex out, and the knight's mana bar is public information. Both players are reading the same
-- two numbers.
--
-- The two gates are the usual pair and they do different jobs (see the note on payCost in
-- models/trait.lua): the cooldown paces answers WITHIN an exchange -- you unravel one spell per
-- recharge, so a second caster in the same flurry gets through -- and the mana bounds them ACROSS the
-- battle. A bearer who counters everything early has nothing left to counter the thing that mattered,
-- which is the choice the trait is selling.
--
-- Single-target only, like the mirrors: an area spell has no single thread to unpick, so a Fireball
-- goes through it. And it answers spells alone -- a sword is not something you can unweave.
return {
    name = "Counter Magic",
    description = "A single-target spell aimed at you is unravelled entirely, for mana.",
    magnitude = 10, -- ticks before the reflex can answer another spell
    cost = { stat = "mana", amount = 14 }, -- paid on every firing; an empty pool means no counter
    countersSpell = true,
}
