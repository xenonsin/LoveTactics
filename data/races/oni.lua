-- Oni: the horned clan of Wrath's Cinderfall Flows, and the circle's third race. Reviewed over two rounds,
-- 2026-09-26/27 ("The Oni of Wrath"), inspired by the oni of Reincarnated as a Slime and Re:Zero -- the
-- premises, never the cast.
--
-- VENGEANCE FOR THEIR OWN. The goblins avenge a hit and the orcs feed on a fall; an oni avenges a DEATH. Its
-- power lives in the horn, and the horn comes out when the oni is wounded past half or sees one of its clan
-- felled -- then it hits harder, moves faster, heals, and goes for whoever did the killing (Horn Out). A
-- critical hit snaps the horn, and an oni without one is open to every weapon and cannot cast again. That is
-- the lever the company holds: snap horns first, or choose the order the clan dies in.
--
-- THE HORN IS THE DEFENSE, SO THE RACE LINE STAYS EMPTY. The approved reading was +1 to all three physical
-- types while the horn stands and -1 once it is snapped. A racial resist must sum to zero (the innate contract,
-- tests/bestiary_spec.lua), so the +1 rides the horn itself (utility_oni_blood) and the snap lays the -1 on top
-- (status_horn_snapped). The race says what an oni is; the horn says what it is wearing.
--
-- THE STAT LINE is precision (damage +1, skill +1): few of them to a fight, trained, and quick to crit. The review
-- asked for skill +2; a race line is held to a budget of 2 (tests/race_spec.lua), so skill gave up the point.
--
-- THE WITCH'S TAINT: an oni smells a hex, and goes first for whoever carries one (trait_witchs_taint).
--
-- PLAYABLE (approved): a hired oni goes Horn Out when a companion falls, can have its horn snapped by an enemy
-- crit, and smells a hexed foe. The compulsions are the AI's, and an AI rule binds no player body.
return {
    name = "Oni",
    description = "Horned clan of the flows. Kill one, and the rest come for you.",
    kind = "humanoid",
    bonus = {
        damage = 1, -- they hit hard...
        skill = 1,  -- ...and exactly
    },
    grants = { "utility_oni_blood" },
}
