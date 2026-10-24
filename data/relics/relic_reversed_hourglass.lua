-- RARE. Time runs one way for the company. What it lays on a foe stays laid for the rest of the fight --
-- a Burn burns until the fight ends -- and what it wears runs out in half the time, its own blessings
-- included.
--
-- The Open Wound's mirror, and it keeps that relic's carve-out for the same reason: hard control (a
-- Stun, a Freeze, a Sleep) still wears off a foe, or one stun would end the fight for somebody. So does
-- a status whose ENDING does something (Charm handing a body back, a fuse that bursts) -- models/
-- status.lua's Status.ageRate. If the company also holds The Open Wound, its statuses never run out at
-- all: never beats sooner.
--
-- THE RULE FIRES ONCE, and it has no magnitude to grow -- forever is already forever. The ladder is a
-- small compensation in the same currency, time: +1 speed per copy, so a company in a hurry comes
-- around the turn order a little sooner.
return {
    name = "The Reversed Hourglass",
    blurb = "Statuses the company lays on foes never run out (stuns and sleeps still do). +%d speed.",
    tier = "rare", mark = "Rh",
    cost = "Statuses on the company last half as long.",
    scale = { 1, 1 },
    bonus = { speed = 1 },
    bonusStep = { speed = 1 },
    rules = { reversedHourglass = true },
}
