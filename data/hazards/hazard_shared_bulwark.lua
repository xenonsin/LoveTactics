-- A Shared Bulwark: the ground a raised greatshield covers. Every ALLY standing in it carries a
-- physical barrier -- one blow, swallowed whole.
--
-- The most valuable thing in this file, and the reason it needs its narrow shape. A barrier negates a
-- hit OUTRIGHT rather than reducing it (Status.barrierAgainst), so handing one to the whole line is
-- categorically stronger than handing the whole line armor. What keeps it fair is that the barrier is
-- ZONE-BOUND: it lifts the instant its bearer steps off the covered ground, so the line only has it
-- while the line is actually standing behind the shield. Spread out to flank and you are bare.
--
-- Which makes the item a statement about how the party should fight rather than a stat: it rewards the
-- formation this game's AoE most wants to punish, and the two pressures are supposed to argue. A
-- fireball into a bulwarked line is answered by five barriers; a fireball into a line that clumped up
-- for a bulwark it has already spent is answered by nothing.
--
-- One charge, refreshed whenever a fresh beat re-lays the ground under a unit that has spent its own
-- (Hazard.place re-runs onEnter, and Status.apply refreshes rather than stacks). So the bulwark eats
-- roughly one blow per body per beat, which is a real ceiling and the reason it cannot simply win.
return {
    name = "Shared Bulwark",
    description = "Covered ground: allies standing in it turn aside the next physical blow.",
    sprite = "assets/hazards/shared_bulwark.png",
    tags = { "structure" },
    duration = 6,
    disposition = "friendly",
    onEnter = function(ctx)
        if not ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_physical_barrier")
    end,
}
