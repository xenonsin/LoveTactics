-- Moxie: the kitchen skill on the Cafe's most expensive order, The Empty Chair. Once a battle, the blow that would
-- drop you does not -- you come up on a sliver instead.
--
-- Monster Hunter's Felyne Moxie, and the reason it is the premium order there is the reason it is here:
-- it does not make you stronger, it buys back the mistake. On a board where a fallen member starts a
-- countdown toward a corpse (docs/downed.md), refusing one death across a whole company is the most
-- valuable thing the counter sells.
--
-- Rides `revivesOnLethal`, the standing reflex Combat.dealFlatDamage consults at the death threshold --
-- the same mechanism trait_second_wind uses, so no new combat path exists for this.
--
-- WHAT IS DIFFERENT IS `revivesAt`. Second Wind stands its bearer back up at HALF health, and it is
-- priced as a relic and as a general's own rule -- one body, earned. This is four bodies, bought with
-- gold, and at half health apiece it would be the only thing anybody ever ordered. At 0.15 it is what it
-- ought to be: not a second life, a second CHANCE -- you are still nearly dead, still standing in
-- whatever killed you, and the turn you have been handed had better be spent getting out.
return {
    name = "Moxie",
    description = "Once per battle, survive a lethal blow and come up on a sliver of health.",
    revivesOnLethal = true, -- read by Trait.trySurvive (models/trait.lua) at the death threshold
    revivesAt = 0.15,       -- a sliver, not the half a relic's Second Wind pays
}
