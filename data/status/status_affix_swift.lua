-- Swift: the BADGE an affixed body wears (models/affix.lua, data/affixes/affix_swift.lua). It does
-- nothing on its own -- the affix's rules ride its traits and its own statuses -- and exists so the affix
-- reads where every other buff on a body reads: the badge row on the token and the status list, rather
-- than a letter of its own in the token's corner (the author, 2026-10-25: "use the buff system").
-- Applied at the bell by Affix.open; it lasts the fight, quotes no countdown, and nothing cleanses it.
return {
    name = "Swift",
    abbr = "Swft",
    description = "Has +2 Move, and opens the fight Hasted.",
    color = { 0.88, 0.80, 0.47 },
    duration = 9999,
    hideDuration = true,
    debuff = false,
    affix = "affix_swift", -- the tile tooltip names the affix itself, so its status list skips this row
}
