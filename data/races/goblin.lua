-- Goblin: the wiry, thick-skulled folk of Wrath's Cinderfall Flows, and the circle's first race.
-- Reviewed over two rounds, 2026-09-26 ("The Goblins of Wrath").
--
-- RAGE WITH NO PLAN. A goblin does not pick its target: it goes for whoever last hurt one of its kin, and
-- so does every goblin on the board (Blood Feud). That is what makes a warband dangerous, and it is also
-- the lever the company holds -- whoever opens the fight decides who the warband chases. The dwarves seek
-- the heap and the kobolds their dragon; a goblin seeks whoever just hit one of them.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 slash, +1 impact, -2 pierce), the innate contract held: wiry enough to
-- slip a blade, thick-skulled enough to take a club, and an arrow finds them. So the three underground
-- races each fall to a different weapon -- a hammer for the dwarves, a sword for the kobolds, a bow for the
-- goblins. No element, for the kobolds' reason: fire is this circle's ground, and a race resisting it would
-- flatten the circle's own hazard.
--
-- THE STAT LINE is that it hits first and hits hard (damage +1, speed +1), with nothing spent on defense.
--
-- BLOOD FEUD IS GRANTED rather than authored into eleven grids (utility_blood_feud): the Feud itself and
-- Mob Courage -- a goblin with no kin within two cowers, the alpha and the elite excepted. Bound and
-- unstealable: an organ, not kit.
--
-- PLAYABLE (approved): a company may hire one, and a hired goblin wears Blood Feud too -- it hits harder
-- against whoever last hit a goblin. The compulsion is the AI's, and an AI rule binds no player body.
return {
    name = "Goblin",
    description = "Wiry, thick-skulled folk of the flows. Hit one, and all of them come for you.",
    kind = "humanoid",
    resist = {
        slash = 1,   -- wiry enough to slip a blade...
        impact = 1,  -- ...thick-skulled enough to take a club...
        pierce = -2, -- ...and an arrow finds them. Sums to zero.
    },
    bonus = {
        damage = 1, -- it hits hard...
        speed = 1,  -- ...and first
    },
    grants = { "utility_blood_feud" },
}
