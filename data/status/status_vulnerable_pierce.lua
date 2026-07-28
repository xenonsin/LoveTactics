-- Vulnerable: Pierce -- the flesh is opened to the point and the barb. A flat pre-mitigation bonus to
-- any `pierce`-tagged hit on the bearer (`vulnerable`, folded into Combat.mitigatedDamage).
--
-- The MOBILE cousin of Exposed (data/status/status_exposed.lua), which is the same +pierce weakness but
-- ZONE-BOUND -- it lasts only while its bearer stands in the Coveted Blood cloud, so a ranged party
-- cannot reliably use it. This one is a plain debuff a hunter can pin on a chosen target from range and
-- then walk away from. One tag, the case for which Exposed makes at length: it is worth nothing beside
-- three axes and a great deal beside a bow, a spear and a dagger. See docs/vulnerability.md.
return {
    name = "Vulnerable: Pierce",
    abbr = "Vpi",
    description = "Marked open: takes extra damage from piercing hits.",
    color = { 0.769, 0.345, 0.431 }, -- badge tint (open red, kin to Exposed)
    fx = { field = true },
    duration = 10,           -- a touch shorter than the melee openers: a hunter's mark, spent at range
    debuff = true,
    vulnerable = { pierce = 8 },
}
