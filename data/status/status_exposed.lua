-- Exposed: the flesh is open. A flat pre-mitigation bonus to any `pierce`-tagged hit that lands on
-- this unit (`vulnerable`, folded into Combat.mitigatedDamage exactly as Wet's lightning weakness and
-- Frozen's brittleness are). It does nothing whatsoever on its own.
--
-- Granted only by standing in the Coveted Blood's cloud (data/hazards/hazard_exposure.lua), and
-- ZONE-BOUND: it declares no `lingers`, so it does not age at all and it ends the instant a live zone
-- granting it is no longer underneath its bearer (see the contract at the top of models/hazard.lua).
-- Walk out and you are whole again. That is what makes the item that lays it a positional weapon
-- rather than a debuff -- the alchemist has to keep standing next to the thing it wants killed.
--
-- PIERCE alone, and that narrowness is the design rather than an oversight. A vulnerability to
-- everything would just be a damage buff painted on the enemy; a vulnerability to one hit tag is a
-- question asked of the party's whole loadout -- it is worth nothing beside three axes and a great
-- deal beside a bow, a spear and a dagger. Envy's item makes other people's kit better or it makes
-- nothing better, and which one depends on kit you chose long before you bought it.
return {
    name = "Exposed",
    abbr = "Exp",
    description = "Exposed: takes extra damage from piercing hits.",
    color = { 0.72, 0.20, 0.32 }, -- badge tint (open red)
    duration = 10,
    debuff = true, -- removable by Cure, though walking out of the cloud is cheaper
    vulnerable = { pierce = 8 },
}
