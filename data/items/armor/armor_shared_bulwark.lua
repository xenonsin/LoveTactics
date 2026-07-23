-- The Shared Bulwark: a tower shield too large for one person to hide behind, which is the point.
-- Every ally standing beside its bearer carries a physical barrier -- one blow, swallowed whole
-- (data/hazards/hazard_shared_bulwark.lua).
--
-- THE STRONGEST THING IN THIS FILE, and its shape is entirely about keeping that fair. A barrier
-- negates a hit OUTRIGHT rather than reducing it (Status.barrierAgainst), so handing one to the whole
-- line is categorically stronger than handing the whole line armor -- an archer's volley and an
-- executioner's stroke are both simply cancelled.
--
-- Three things hold it down, and none of them is a small number:
--
--   * ZONE-BOUND. The barrier lifts the instant its bearer steps off the covered ground, so the line
--     only has it while the line is actually standing behind the shield. Spread out to flank and you
--     are bare. It rewards precisely the formation this game's AoE most wants to punish.
--   * ONE CHARGE PER BODY PER BEAT. The ward refreshes rather than stacks (Status.apply's rule), so
--     the bulwark eats roughly one blow per ally per beat and no more. A focused line still dies; it
--     just dies to the second hit rather than the first.
--   * THE BEARER IS IN THE MIDDLE OF IT. There is no version of this that is held from behind.
--
-- Heavy armor besides, so the wearer is a knight and is going to be standing in the front rank anyway,
-- which is where the whole item wants them.
return {
    name = "The Shared Bulwark",
    description = "Allies standing beside its bearer turn aside the next physical blow entirely.",
    flavor = "The Bastion issues one per company. The requisition form has a line for who will be behind it.",
    sprite = "assets/items/armor_shared_bulwark.png",
    type = "armor",
    tags = { "shield", "heavy" },
    class = "knight",
    price = 520,
    repRank = 4,
    incense = { hazard = "hazard_shared_bulwark", radius = 1 },
    bonus = { defense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
    -- The family contract: a shield swaps its holder's Wait into Defend (docs/weapons.md, enforced by
    -- tests/weapon_spec.lua). Braced a little worse than a plain Bulwark Shield -- what this one is
    -- really paying for is the ground it holds for everyone else, and it should not also be the best
    -- personal guard on the shelf.
    waitBehavior = {
        kind = "defend", speed = 2,
        defense = { 6, 7, 7, 8, 9, 9, 10, 11, 11, 12, 13 },
    },
}
