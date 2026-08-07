-- Vigil Beads: the standing rule of the Theurge's charm. The bearer's channels cannot be interrupted --
-- by anything.
--
-- A flag (Trait.flag) read at the top of Combat.interruptChannel, which is the single door every
-- interruption in the game passes through: a Stun, a Freeze, a Sleep, a Silence on a mana channel, a
-- shove, a Polymorph, a dismissal. One clause closes all of them.
--
-- The distinction against `steadfast`, which already existed, is where the property LIVES. Kingsfall
-- declares `steadfast` on its ability, so one particular greatsword is unbreakable and its wielder is
-- ordinary the moment they put it down. This is on the UNIT, so every channel the theurge owns inherits
-- it -- the Long Prayer, Benediction, Invocation, and anything bought later. One is a weapon's promise;
-- this is a discipline's.
--
-- It is also why the item needs no second effect to justify a grid cell. The draft bundled a speed
-- bonus with it and the author cut that half, correctly: seven statuses in the game break a wind-up,
-- and being immune to all of them at once is not a small thing dressed up, it is the whole purchase.
return {
    name = "Vigil Beads",
    description = "Your channels cannot be interrupted, by anything.",
    steadfastChannels = true,
}
