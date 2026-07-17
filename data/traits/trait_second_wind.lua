-- Second Wind: one refusal to die. The first blow that would drop the bearer instead stands it back
-- up at half its (unreserved) maximum health -- once per battle. The mechanism is a standing reflex,
-- like Dodge: Combat.dealFlatDamage consults Trait.trySurvive the moment a hit reaches 0 HP and, if
-- this trait is unspent (`stacks == 0`), voids the death and latches the charge. A pure marker with
-- no hooks -- the rule lives in the damage core so any relic that grants it revives exactly the same.
return {
    name = "Second Wind",
    description = "Once per battle, survive a lethal blow and rise at half health.",
    revivesOnLethal = true, -- read by Trait.trySurvive (models/trait.lua) at the death threshold
}
