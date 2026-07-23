-- Bloodsong: the thirst, shared out. A smaller share than the Red Thirst pays its bearer, granted to
-- every ally standing in the standard's smoke rather than to one body -- the same `lifesteal` flag,
-- read through the same fold (Status.lifesteal), differing only in size and in who gets it.
--
-- ZONE-BOUND. It declares no `lingers`, so the grant is stamped with the hazard that laid it and it
-- lifts the moment its bearer steps out of the smoke or the standard-bearer falls (models/hazard.lua).
-- That is the whole shape of the item that carries it (utility_crimson_standard): it is ground that
-- WALKS, laid around its bearer every time they move (Combat.layIncense), so the company drinks only
-- while it fights in formation around whoever is holding the colours.
--
-- Which makes it the first team-wide aura this game has had, and worth being precise about why it took
-- this shape. The 3x3 grid's auras are the game's signature idea, and they are deliberately intimate:
-- one charm, the items it touches, one character. A LINE-wide effect is a different scale of thing and
-- needed a different mechanism -- and the mechanism already existed, in the censer family, doing
-- exactly this for exactly one class. Nothing new was invented here; something narrow was widened.
return {
    name = "Bloodsong",
    abbr = "Bsng",
    description = "Bloodsong: drinks back a share of the damage it deals.",
    color = { 0.84, 0.34, 0.36 }, -- badge tint (banner red)
    duration = 6,                 -- the backstop; the smoke under it is what really holds this up
    lifesteal = 0.25,             -- the shared share: a quarter, against the Red Thirst's three
}
