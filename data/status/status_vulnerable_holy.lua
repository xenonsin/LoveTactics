-- Vulnerable: Holy -- the target is branded anathema, and holy light bites it far deeper for a time. A
-- flat pre-mitigation bonus to any `holy`-tagged hit on the bearer (`vulnerable`, folded into
-- Combat.mitigatedDamage).
--
-- Holy is a whole element that had no vulnerability path at all, and the one with the strongest fiction
-- for one: you do not resist a judgment, you are named for it. One tag, on purpose (see
-- status_vulnerable_slash): worth nothing beside a party of steel, and a great deal beside censers, the
-- Demon-Bane, and every consecrated edge. Reads as vicious against demons and the church's own blooded
-- sleepers. See docs/vulnerability.md for the family.
return {
    name = "Vulnerable: Holy",
    abbr = "Vho",
    description = "Anathema: takes extra damage from holy attacks.",
    color = { 0.910, 0.816, 0.541 }, -- badge tint (accusing gold)
    fx = { field = true },
    duration = 12,
    debuff = true,
    vulnerable = { holy = 8 },
}
