-- Vulnerable: Pierce -- the flesh is opened to the point and the barb. A flat pre-mitigation bonus to
-- any `pierce`-tagged hit on the bearer (`vulnerable`, folded into Combat.mitigatedDamage exactly as
-- Wet's lightning weakness and Frozen's brittleness are). It does nothing whatsoever on its own.
--
-- PIERCE alone, and that narrowness is the design rather than an oversight. A vulnerability to
-- everything would just be a damage buff painted on the enemy; a vulnerability to one hit tag is a
-- question asked of the party's whole loadout -- it is worth nothing beside three axes and a great
-- deal beside a bow, a spear and a dagger. Envy's cloud makes other people's kit better or it makes
-- nothing better, and which one depends on kit you chose long before you bought it.
-- See docs/vulnerability.md for the family this belongs to.
--
-- ZONE-BOUND OR FREE-STANDING, depending on who grants it, and the status says nothing either way.
-- It declares no `lingers`, so a HAZARD that grants it (the Coveted Blood cloud, the Muster banner,
-- a spoil heap) has its id stamped on the instance as `source` by models/hazard.lua's applyStatus --
-- which means it does not age at all and lifts the instant no live zone granting it sits underneath
-- its bearer. Walk out of the cloud and you are whole again. An ABILITY, weapon or trait that grants
-- it stamps no source, so the same mark pinned from range runs its own duration and travels with the
-- body. One status, both lifetimes, decided by the deliverer -- which is what let Exposed fold into
-- this one rather than stand beside it.
--
-- THAT MERGE, since the two files argued with each other for a while: Exposed was this same
-- `vulnerable = { pierce = 8 }` for the same 10 ticks under a second name, and Status.vulnerability
-- SUMS across statuses -- so a body wearing both took +16 from pierce off two badges printing the one
-- sentence. Folded this way round (Exposed's deliverers retargeted here) because the plain
-- `Vulnerable: <Type>` badge is the family's naming contract and the flavour belongs on the deliverer,
-- which still says Exposing Pike and Coveted Blood on the tin.
--
-- One interaction the merge creates, and it is the right way round: a dart fired into the cloud
-- REFRESHES the zone's instance rather than laying a second one, and Status.apply leaves `source`
-- alone on a refresh -- so that mark lifts with the cloud. A hunter who wants the travelling version
-- fires at a body standing on clean ground, which is the decision the two statuses were pretending to
-- offer while actually just paying double.
return {
    name = "Vulnerable: Pierce",
    abbr = "Vpi",
    description = "Marked open: takes extra damage from piercing hits.",
    color = { 0.769, 0.345, 0.431 }, -- badge tint (open red)
    fx = { field = true },
    duration = 10,
    debuff = true, -- removable by Cure, though walking out of the cloud is cheaper
    vulnerable = { pierce = 8 },
}
