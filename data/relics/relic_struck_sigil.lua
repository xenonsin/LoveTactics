-- COMMON. The caster's Whetstone Tithe. Magic damage is its own stat and its own mitigation ladder
-- (magicDefense), so a company built around casters was, before this, unable to buy the one thing the
-- swordline could -- a flat point of hitting harder.
return {
    name = "The Struck Sigil",
    blurb = "+%d magic damage for the whole company.",
    tier = "common", mark = "Si",
    scale = { 1, 1 },
    bonus = { magicDamage = 1 },
}
