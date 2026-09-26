-- Orc: the heavy, scarred folk of Wrath's Cinderfall Flows, beside the goblins, and the circle's second race.
-- Reviewed over two rounds, 2026-09-26 ("The Orcs of Wrath").
--
-- EVERY KILL MAKES ONE STRONGER. A goblin punishes whoever hits its kin (Blood Feud); an orc punishes a company
-- that lets somebody fall. A killing blow makes an orc Proven -- +2 Damage and +2 Defense for the fight, three
-- times -- and the warband's heads (the Warchief's succession, the Blood-Caller's offering) are built on it. The
-- company's lever is kill order, and keeping its wounded out of reach.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 pierce, +1 impact, -2 slash), the innate contract held: a thick hide turns an
-- arrow and heavy bone takes a club, but a blade opens them. The goblins fall to the bow, so a company in Wrath
-- now wants a bow AND a blade. No element, for the goblins' reason: fire is this circle's ground.
--
-- THE STAT LINE is that it hits hard and takes a blow (damage +1, defense +1). Goblins are fast and frail; orcs
-- are slow and sturdy, and the slowness is set on each body's own sheet, since Race.STAT_BUDGET is 2.
--
-- PROVEN IS GRANTED rather than authored into ten grids (utility_proven). Bound and unstealable. Orcs never cower.
--
-- PLAYABLE (approved): a company may hire one, and a hired orc wears Proven too.
return {
    name = "Orc",
    description = "Heavy, scarred folk of the flows. Every kill makes one stronger.",
    kind = "humanoid",
    resist = {
        pierce = 1,  -- a thick hide turns an arrow...
        impact = 1,  -- ...heavy bone takes a club...
        slash = -2,  -- ...and a blade opens them. Sums to zero.
    },
    bonus = {
        damage = 1,  -- it hits hard...
        defense = 1, -- ...and takes a blow
    },
    grants = { "utility_proven" },
}
