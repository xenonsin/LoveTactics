-- CRACKED RIBS: the only kind that makes the NEXT fall likelier.
--
-- Three points off Defense, so everything the floor throws lands harder on a body that has already been
-- carried out once. Every other injury in the set costs the company OUTPUT -- reach, damage, aim, a pool
-- -- and this one costs it the body.
--
-- WHICH MAKES IT THE ONE THAT SHOULD MAKE A PLAYER TURN BACK, and the one worth watching in play for
-- exactly that reason. A meter that compounds is how a game turns a bad trip into a bad campaign, and
-- the whole shape of this system (a floored reserve, a floored stat, an unbounded bench, free recovery)
-- is built to stop that happening. This is the one piece of it that pushes the other way, deliberately
-- and once: three points against a roster whose Defense is authored on a 5-14 band is a real bite and
-- not a spiral, and the floor at a quarter of base catches the body that takes it twice.
return {
    name = "Cracked Ribs",
    description = "Cracked Ribs: takes more from every blow.",
    severity = 2,
    weight = 15,
    reserve = { health = 0.06 },
    effects = { { id = "status_cracked_ribs" } },
}
