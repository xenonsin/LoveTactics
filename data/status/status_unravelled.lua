-- Unravelled: the weave that holds this body together has been picked loose, and magic pours into the
-- gap. A flat pre-mitigation bonus to every `magical` hit that lands on the bearer, folded into
-- Combat.mitigatedDamage exactly as Wet's lightning weakness and Exposed's opening to pierce are.
--
-- The magical twin of Exposed, and deliberately built on the same narrow principle: it amplifies ONE
-- school rather than everything. A blanket vulnerability is just a damage buff painted on the enemy;
-- a vulnerability to one school is a question asked of the party's whole loadout, worth nothing beside
-- three axes and a great deal beside a wand, a censer and a bottle of liquid fire.
--
-- It reaches for the `magical` tag rather than for the elements, and that is the reason it is a single
-- status and not five: every spell in this game carries `magical` alongside whatever else it carries
-- (see Combat.dealDamage's school routing), so fire, ice, lightning, arcane, holy and dark are all
-- amplified by one line, at one number, that a player can read once.
--
-- ZONE-BOUND. It declares no `lingers`, so the grant is stamped with the zone that laid it and it ends
-- the instant its bearer steps off the picked ground or the ground itself settles (models/hazard.lua).
-- That is what makes the lens that lays it a POSITIONAL weapon rather than a debuff: the caster has to
-- keep the fight on the tiles they chose.
return {
    name = "Unravelled",
    abbr = "Unrv",
    description = "Unravelled: takes extra damage from every magical hit.",
    color = { 0.70, 0.42, 0.86 }, -- badge tint (picked-loose violet)
    duration = 10,
    debuff = true,
    vulnerable = { magical = 7 },
}
