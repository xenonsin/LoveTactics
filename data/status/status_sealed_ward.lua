-- Sealed Ward: one hostile working, aimed squarely at this body, simply does not happen.
--
-- Not a barrier. A barrier is spent by DAMAGE and swallows whatever lands; this is spent by a SPELL
-- BEING AIMED and swallows the whole working -- its damage, its status, its shove, its summon, all of
-- it, before the effect runs at all (see the gate at the top of resolveCast in models/combat.lua).
-- A spell that would have dealt nothing and only rooted you is stopped exactly as hard as a nuke,
-- which is the entire reason to carry one.
--
-- Three things make it fair, and all three are aimed at the same idea -- that the counterplay should be
-- a decision rather than a bigger number:
--
--   * SINGLE TARGET ONLY. An area effect that catches the bearer among others goes straight past it.
--     A blast does not aim at anybody, so there is nothing for the seal to refuse. This is the standing
--     answer, available to every class that owns an aoe, and it needs no knowledge of the item at all.
--   * ONE CHARGE. `magnitude` counts what it will still refuse, spent through Status.consumeBarrier
--     exactly as a barrier's charges are. The second spell that turn lands.
--   * THE CASTER STILL PAID. Cost, cooldown, and the turn itself are all gone. The seal costs its
--     enemy a whole action -- which means baiting it out is a real play, and so is declining to.
--
-- Long duration on purpose: it is granted by a relic that is holding it up (utility_sealed_reliquary),
-- and a ward that lapsed before anyone tested it would just be a slot that did nothing all fight.
return {
    name = "Sealed Ward",
    abbr = "Seal",
    description = "Sealed: the next single-target spell aimed at it is refused outright.",
    color = { 0.86, 0.80, 0.52 }, -- badge tint (old gold: a seal, not a shield)
    duration = 40,                -- ~8 turns: the relic holds it up, so it waits to be tested
    magnitude = 1,                -- workings it refuses before it is spent
    negates = "cast",
}
