-- Second Wind: one refusal to die. The first blow that would drop the bearer instead stands it back
-- up at half its (unreserved) maximum health -- once per battle. The mechanism is a standing reflex,
-- like Dodge: Combat.dealFlatDamage consults Trait.trySurvive the moment a hit reaches 0 HP and, if
-- this trait is unspent (`stacks == 0`), voids the death and latches the charge. A pure marker with
-- no hooks -- the rule lives in the damage core so any relic that grants it revives exactly the same.
--
-- HOW FAR IT STANDS YOU BACK UP IS THE GRANTER'S CALL, not this file's. Half by default, which is what
-- a relic and a general's own rule are priced at -- but the Cafe's Empty Chair hands the whole company
-- the same refusal and must not hand it the same recovery: a supper that stood eight bodies up at half
-- health would be the only thing on the menu anybody ever ordered, so it names a sliver instead
-- (data/meals/meal_empty_chair.lua's `skillParams`). That used to be a SECOND TRAIT, Moxie, identical
-- to this one but for the fraction; it is now this trait with a different number, read through
-- Trait.param.
return {
    name = "Second Wind",
    description = "Once per battle, survive a lethal blow and rise at half health.",
    revivesOnLethal = true, -- read by Trait.trySurvive (models/trait.lua) at the death threshold
    revivesAt = 0.5,        -- the share of the unreserved bar; a granter may name its own
}
