-- Thorned: the BADGE an affixed body wears (models/affix.lua, data/affixes/affix_thorned.lua). It does
-- nothing on its own -- the affix's rules ride its traits and its own statuses -- and exists so the affix
-- reads where every other buff on a body reads: the badge row on the token and the status list, rather
-- than a letter of its own in the token's corner (the author, 2026-10-25: "use the buff system").
-- Applied at the bell by Affix.open; it lasts the fight, quotes no countdown, and nothing cleanses it.
return {
    name = "Thorned",
    abbr = "Thrn",
    description = "Melee attackers take 40% of the damage they deal back.",
    color = { 0.55, 0.75, 0.35 },
    duration = 9999,
    hideDuration = true,
    debuff = false,
    affix = "affix_thorned", -- the tile tooltip names the affix itself, so its status list skips this row
}
