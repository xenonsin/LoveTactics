-- Substitution: the standing rule of the Ninja's charm of the same name. A blow that would land on the
-- bearer kills a standing clone instead, and the two trade places.
--
-- A flag (Trait.flag) read by Trait.trySubstitute, which sits in Combat.dealFlatDamage beside the Dodge
-- and Smoke reflexes and returns before mitigation -- so the blow deals nothing, grants no rage and
-- provokes no counter. Nothing landed on anyone still standing.
--
-- What separates it from those two: they are free and gated on a cooldown; this spends a conjuration
-- the ninja had to cast first, and drops the ninja onto a tile it did not choose. The clone stops being
-- scenery for the enemy AI to waste a swing on and becomes a resource with a second use.
return {
    name = "Substitution",
    substitutes = true,
}
