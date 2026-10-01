-- Elf: the long-lived folk of Pride's spire, and the circle's first race. Reviewed 2026-09-30 ("Pride's
-- Bestiary", rounds 1-2).
--
-- PERFECTION IS A STATE, AND IT IS LOST ONCE. Every elf opens a fight Unblemished (status_unblemished): a
-- large lift to everything it does, reach included, that the first blow to draw its blood takes away for the
-- rest of the fight. A heal does not give it back -- Pride does not repent, and a wound cannot be unadmitted.
-- So the lever a company holds is breadth, not focus: a cleave, a Rain or a volley that marks every elf once
-- is worth more on the spire than one great blow on one of them.
--
-- THE PHYSICAL THREE SUM TO ZERO (+1 slash, +1 pierce, -2 impact): fine-boned, so an edge slides off a body
-- that turns and an arrow finds little to hold, but a club breaks what both of those missed. The dwarves fall
-- to the hammer too; they stand on another circle.
--
-- THE STAT LINE is that it hits true (skill +2). Goblins took speed and orcs took damage.
--
-- UNBLEMISHED IS GRANTED rather than authored into every grid (utility_elf_blood), bound and unstealable: an
-- organ, not kit.
--
-- PLAYABLE (approved): a company may hire one, and a hired elf wears the rule too -- a player who keeps their
-- elf untouched is paid for it.
return {
    name = "Elf",
    description = "Long-lived folk of the spire. Flawless until the first wound, and never again after it.",
    kind = "humanoid",
    resist = {
        slash = 1,   -- an edge slides off a body that turns...
        pierce = 1,  -- ...an arrow finds little to hold...
        impact = -2, -- ...and a club breaks what both missed. Sums to zero.
    },
    bonus = {
        skill = 2, -- it hits true
    },
    grants = { "utility_elf_blood" },
}
